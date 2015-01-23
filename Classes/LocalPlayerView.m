// Copyright 2014 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.


#import <AVFoundation/AVFoundation.h>
#import "LocalPlayerView.h"
#import "SimpleImageFetcher.h"

/* Internal state of the view. */
typedef NS_ENUM(NSInteger, LpvState) {
  LpvSplash,
  LpvPlaying,
  LpvPaused,
  LpvCastingOther,
  LpvCastingCurrentMedia
};

/* Time to wait before hiding the toolbar. UX is that this number is effectively doubled. */
static NSInteger kToolbarDelay = 3;
/* The height of the toolbar view. */
static NSInteger kToolbarHeight = 44;

@interface LocalPlayerView() {
  LpvState _state;
}

/* The splash image to display before playback or while casting. */
@property UIImageView *splashImage;
/* AVPlayer used to play locally. */
@property(nonatomic) AVPlayer *moviePlayer;
/* The CALayer on which the video plays. */
@property(nonatomic) AVPlayerLayer *playerLayer;
/* The UIView used for receiving control input. */
@property(nonatomic) UIView *controlView;
/* The media we are playing. */
@property(nonatomic) Media *mediaToPlay;
/* Opaque observer reference for the played duration observer. */
@property(nonatomic) id playerObserver;
/* Time played. */
@property(nonatomic) Float64 duration;
/* Whether there has been a recent touch, for fading controls when playing. */
@property(nonatomic) BOOL recentInteraction;
/* The gesture recognizer used to register taps to bring up the controls. */
@property(nonatomic) UIGestureRecognizer *singleFingerTap;


/* Views dictionary used to the layout management. */
@property(nonatomic) NSDictionary *viewsDictionary;
/* Views dictionary used to the layout management. */
@property(nonatomic) NSArray *constraints;
/* Play/Pause button. */
@property(nonatomic) UIButton *playButton;
/* Playback position slider. */
@property(nonatomic) UISlider *slider;
/* Label displaying length of video. */
@property(nonatomic) UILabel *totalTime;
/* Label displaying current play time. */
@property(nonatomic) UILabel *currTime;
/* View for containing play controls. */
@property(nonatomic) UIView *toolbarView;
/* Play image. */
@property(nonatomic) UIImage *playImage;
/* Pause image. */
@property(nonatomic) UIImage *pauseImage;
/* Loading indicator */
@property(nonatomic) UIActivityIndicatorView *activityIndicator;

@end

@implementation LocalPlayerView

# pragma mark - Lifecycle

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

# pragma mark - Layout Managment

- (void)layoutSubviews {
  CGRect frame = [self fullscreen] ? [UIScreen mainScreen].bounds :
                                      [self fullFrame];
  if ((NSFoundationVersionNumber <= NSFoundationVersionNumber_iOS_7_1) &&
      [self fullscreen]) {
    // Below iOS 8 the bounds don't change with orientation changes.
    frame.size = CGSizeMake(frame.size.height, frame.size.width);
  }

  [self.splashImage setFrame:frame];
  [self.playerLayer setFrame:frame];
  [self.controlView setFrame:frame];
  [self layoutToolbar:frame];
  self.activityIndicator.center = self.controlView.center;
}

/* Update the frame for the toolbar. */
- (void)layoutToolbar:(CGRect)frame {
  [self.toolbarView setFrame:CGRectMake(0,
                                        frame.size.height - kToolbarHeight,
                                        frame.size.width,
                                        kToolbarHeight
                                        )];
}

/* Return the full frame with no offsets. */
- (CGRect)fullFrame {
  return CGRectMake(0, 0, self.frame.size.width, self.frame.size.height);
}

# pragma mark - Interface

/* If given a new media, allocate a media player and the various layers needed. */
- (void)setMedia:(Media *)media {
  if (_mediaToPlay == media) {
    // Don't reinit if we already have the media.
    return;
  }
  self.translatesAutoresizingMaskIntoConstraints = NO;
  _mediaToPlay = media;
  _state = LpvSplash;

  _splashImage = [[UIImageView alloc] initWithFrame:[self fullFrame]];
  [_splashImage setBackgroundColor:[UIColor yellowColor]];
  _splashImage.contentMode = UIViewContentModeScaleAspectFill;
  _splashImage.clipsToBounds = YES;
  [self addSubview:_splashImage];

  _controlView = [[UIView alloc] init];
  self.singleFingerTap = [[UITapGestureRecognizer alloc]
                            initWithTarget:self
                                    action:@selector(didTouchControl:)];
  [_controlView addGestureRecognizer:self.singleFingerTap];
  [self addSubview:_controlView];

  [self initialiseToolbarControls];

  [self loadMovieImage];
  [self configureControls];
}

- (void)loadMoviePlayer {
  if (!self. moviePlayer) {
    self.moviePlayer = [AVPlayer playerWithURL:self.mediaToPlay.URL];
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.moviePlayer];
    [_playerLayer setFrame:[self fullFrame]];
    [_playerLayer setBackgroundColor:[[UIColor blackColor] CGColor]];
    [self.layer insertSublayer:_playerLayer above:_splashImage.layer];
  }

}

/* YES if we the local media is playing or paused, NO if casting or on the splash screen. */
- (BOOL)playingLocally {
  return _state == LpvPlaying || _state == LpvPaused;
}

/* Pause local media if playing. */
- (void)pause {
  if (_state == LpvPlaying) {
    [self playButtonClicked:self];
  }
}

/* Update the local state based on the Cast connection. */
- (void)setCastMode:(LPVCastMode)castMode {
  switch(castMode) {
    case LPVCastUnavailable:
      _castMode = LPVCastUnavailable;
      if (_state == LpvCastingOther || _state == LpvCastingCurrentMedia) {
        _state = LpvSplash;
      }
      break;
    case LPVCastAvailable:
      if (_state == LpvCastingOther || _state == LpvCastingCurrentMedia) {
        _state = LpvSplash;
      }
      _castMode = LPVCastAvailable;
      break;
    case LPVCastConnected:
      _state = LpvCastingOther;
      _castMode = LPVCastAvailable;
      break;
    case LPVCastPlaying:
      _state = LpvCastingCurrentMedia;
      _castMode = LPVCastAvailable;
      break;
  }
  [self configureControls];
}

/* Returns YES if we should be in fullscreen. */
- (BOOL)fullscreen {
  return (_state == LpvPlaying || _state == LpvPaused) &&
      UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation);
}


/* If the orientation changes, display the controls. */
- (void)orientationChanged {
  if ([self fullscreen]) {
    [self setFullscreen];
  }
  [self didTouchControl:nil];
}

- (void)setFullscreen {
  CGRect screenBounds = [UIScreen mainScreen].bounds;
  if (!CGRectEqualToRect(screenBounds, self.frame)) {
    [self.controller hideNavigationBar:YES];
    [self.controller setNavigationBarStyle:LPVNavBarTransparent];
    [self setFrame:screenBounds];
  }
}

# pragma mark - video management

/* Asynchronously load the splash screen image. */
- (void)loadMovieImage {
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

  dispatch_async(queue, ^{
    UIImage *image = [UIImage
              imageWithData:[SimpleImageFetcher getDataFromImageURL:self.mediaToPlay.thumbnailURL]];

    dispatch_sync(dispatch_get_main_queue(), ^{
        _splashImage.image = image;
        [_splashImage setNeedsLayout];
    });
  });
}

/* Callback registered for when the AVPlayer completes playing of the media. */
- (void)movieDidFinish {
  _state = LpvSplash;
  _duration = 0;
  _playbackTime = 0;
  if (self.moviePlayer && self.playerObserver) {
    [self.moviePlayer removeTimeObserver:self.playerObserver];
    self.playerObserver = nil;
  }
  [self removeEndMovieObserver];
  [self.controller setNavigationBarStyle:LPVNavBarDefault];
  [self.moviePlayer seekToTime:CMTimeMake(0, 1)];
  [self configureControls];
}

/* Remove the AVPLayer movie ending observer. */
- (void)removeEndMovieObserver {
  if (self.moviePlayer.currentItem) {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:self.moviePlayer.currentItem];
    [self.moviePlayer.currentItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [self.moviePlayer.currentItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
  }
}

/* Prefer the toolbar for touches when in control view. */
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  if ([self fullscreen]) {
    if (self.controlView.hidden) {
      [self didTouchControl:nil];
      return nil;
    } else if (point.y > self.frame.size.height - kToolbarHeight) {
      return [self.controlView hitTest:point withEvent:event];
    }
  }

  return [super hitTest:point withEvent:event];
}

/* Register observers for the movie time callbacks and for the end of movie notification. */
- (void)registerMovieStateObservers {
  // We take a weak reference to self to avoid retain cycles in the block.
  __weak LocalPlayerView *self_ = self;
  self.playerObserver = [self.moviePlayer addPeriodicTimeObserverForInterval:CMTimeMake(1, 1)
                                                                       queue:NULL
                                                                  usingBlock:^(CMTime time) {
      [self_ updateTimersForTime:time];
    }];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(movieDidFinish)
                                               name:AVPlayerItemDidPlayToEndTimeNotification
                                             object:self.moviePlayer.currentItem];
  [self.moviePlayer.currentItem addObserver:self
                                 forKeyPath:@"playbackBufferEmpty"
                                    options:NSKeyValueObservingOptionNew
                                    context:nil];
  [self.moviePlayer.currentItem addObserver:self
                                 forKeyPath:@"playbackLikelyToKeepUp"
                                    options:NSKeyValueObservingOptionNew
                                    context:nil];

}

/* Update the current time label based on the time from the AVPlayerItem. */
- (void)updateTimersForTime:(CMTime)time {
  if (self.moviePlayer.currentItem.status != AVPlayerItemStatusReadyToPlay) {
    return;
  }
  if (!self.duration) {
    self.slider.minimumValue = 0;
    self.duration = self.slider.maximumValue =
        CMTimeGetSeconds(self.moviePlayer.currentItem.duration);
    self.slider.enabled = YES;
    [self.activityIndicator stopAnimating];
    NSInteger mins = floor(self.slider.maximumValue / 60);
    NSInteger secs = floor((int)self.slider.maximumValue % 60);
    self.totalTime.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)mins, (long)secs];
  }
  if (self.currTime) {
    self.playbackTime = CMTimeGetSeconds(time);
    self.slider.value = CMTimeGetSeconds(time);
    NSInteger mins = floor(self.slider.value / 60);
    NSInteger secs = floor((int)self.slider.value % 60);
    self.currTime.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)mins, (long)secs];
  }
}

# pragma mark - Controls

/* Take the appropriate action when the play/pause button is clicked - depending on the state this
 * may start the movie, pause the movie, or start or pause casting. */
- (IBAction)playButtonClicked:(id)sender {
  self.recentInteraction = YES;
  if (_state == LpvSplash) {
    [self loadMoviePlayer];
    [self registerMovieStateObservers];
    // Set the current playback time to the stored time unless its almost the end.
    if (_playbackTime > 0 && self.duration && _playbackTime < (self.duration - 20)) {
      [self.moviePlayer seekToTime:CMTimeMake(_playbackTime, 1)];
    }
    // Play the movie.
    [self.moviePlayer play];
    self.slider.enabled = NO;
    [self.activityIndicator startAnimating];
    _state = LpvPlaying;
  } else if (_state == LpvPlaying) {
    [self.moviePlayer pause];
    _state = LpvPaused;
  } else if (_state == LpvPaused) {
    [self.moviePlayer play];
    _state = LpvPlaying;
  } else if (_state == LpvCastingOther) {
    [self.controller didTapPlayForCast];
    _state = LpvCastingCurrentMedia;
  } else if (_state == LpvCastingCurrentMedia) {
    [self.controller didTapPauseForCast];
    _state = LpvCastingOther;
  }
  if ([self fullscreen]) {
    [self setFullscreen];
  }
  [self configureControls];
}

/* If we touch the slider, stop the movie while we scrub. */
- (IBAction)onSliderTouchStarted:(id)sender {
  [self.moviePlayer setRate:0.f];
  self.recentInteraction = YES;
}

/* Once we let go of the slider, restart playback. */
- (IBAction)onSliderTouchEnded:(id)sender {
  [self.moviePlayer setRate:1.0f];
}

/* On slider value change the movie play time. */
- (IBAction)onSliderValueChanged:(id)sender {
  if (self.duration) {
    CMTime newTime = CMTimeMakeWithSeconds(self.slider.value, 1);
    [self.activityIndicator startAnimating];
    [self.moviePlayer seekToTime:newTime];
  } else {
    self.slider.value = 0;
  }
}

/* Config the UIView controls container based on the state of the view. */
- (void)configureControls {
  if (_state == LpvSplash || _state == LpvCastingOther) {
    [self.playButton setImage:self.playImage forState:UIControlStateNormal];
    self.playButton.hidden = NO;
    self.splashImage.layer.hidden = NO;
    self.playerLayer.hidden = YES;
    self.currTime.hidden = YES;
    self.totalTime.hidden = YES;
    self.slider.hidden = YES;

    [self didTouchControl:nil];
  } else if (_state == LpvPlaying || _state == LpvPaused) {
    // Play or Pause button based on state.
    UIImage *image = _state == LpvPaused ? self.playImage : self.pauseImage;
    [self.playButton setImage:image forState:UIControlStateNormal];

    self.playerLayer.hidden = NO;
    self.splashImage.layer.hidden = YES;
    self.playButton.hidden = NO;
    self.currTime.hidden = NO;
    self.totalTime.hidden = NO;
    self.slider.hidden = NO;

    [self didTouchControl:nil];
  } else if (_state == LpvCastingCurrentMedia) {
    [self.playButton setImage:self.pauseImage forState:UIControlStateNormal];

    self.playerLayer.hidden = YES;
    self.splashImage.layer.hidden = NO;
    self.playButton.hidden = NO;
    self.currTime.hidden = YES;
    self.totalTime.hidden = YES;
    self.slider.hidden = YES;
    [self didTouchControl:nil];
  }
  [self setNeedsLayout];
}

- (void)showControls {
  self.toolbarView.hidden = NO;
}

- (void)hideControls {
  self.toolbarView.hidden = YES;
  if ([self fullscreen]) {
    [self.controller hideNavigationBar:YES];
  }
}

/* Initial setup of the controls in the toolbar. */
- (void)initialiseToolbarControls {
  // Play/Pause images.
  self.playImage = [UIImage imageNamed:@"play_light.png"];
  self.pauseImage = [UIImage imageNamed:@"pause_light.png"];

  // Toolbar.
  self.toolbarView = [[UIView alloc] init];
  [self layoutToolbar:[self fullFrame]];

  // Play/Pause button.
  self.playButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.playButton setFrame:CGRectMake(0, 0, 40, 40)];
  [self.playButton setImage:self.playImage forState:UIControlStateNormal];
  [self.playButton addTarget:self
                      action:@selector(playButtonClicked:)
            forControlEvents:UIControlEventTouchUpInside];
  self.playButton.tintColor = [UIColor whiteColor];
  self.playButton.translatesAutoresizingMaskIntoConstraints = NO;

  // Current time.
  self.currTime = [[UILabel alloc] init];
  self.currTime.clearsContextBeforeDrawing = YES;
  self.currTime.text = @"00:00";
  [self.currTime setFont:[UIFont fontWithName:@"Helvetica" size:14.0]];
  [self.currTime setTextColor:[UIColor whiteColor]];
  self.currTime.tintColor = [UIColor whiteColor];
  self.currTime.translatesAutoresizingMaskIntoConstraints = NO;

  // Total time.
  self.totalTime = [[UILabel alloc] init];
  self.totalTime.clearsContextBeforeDrawing = YES;
  self.totalTime.text = @"00:00";
  [self.totalTime setFont:[UIFont fontWithName:@"Helvetica" size:14.0]];
  [self.totalTime setTextColor:[UIColor whiteColor]];
  self.totalTime.tintColor = [UIColor whiteColor];
  self.totalTime.translatesAutoresizingMaskIntoConstraints = NO;

  // Slider.
  self.slider = [[UISlider alloc] init];
  UIImage *thumb = [UIImage imageNamed:@"thumb.png"];
  [self.slider setThumbImage:thumb forState:UIControlStateNormal];
  [self.slider setThumbImage:thumb forState:UIControlStateHighlighted];
  [self.slider addTarget:self
                  action:@selector(onSliderValueChanged:)
        forControlEvents:UIControlEventValueChanged];
  [self.slider addTarget:self
                  action:@selector(onSliderTouchStarted:)
        forControlEvents:UIControlEventTouchDown];
  [self.slider addTarget:self
                  action:@selector(onSliderTouchEnded:)
        forControlEvents:UIControlEventTouchUpInside];
  [self.slider addTarget:self
                  action:@selector(onSliderTouchEnded:)
        forControlEvents:UIControlEventTouchCancel];
  [self.slider addTarget:self
                  action:@selector(onSliderTouchEnded:)
        forControlEvents:UIControlEventTouchUpOutside];
  self.slider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  self.slider.minimumValue = 0;
  self.slider.minimumTrackTintColor = [UIColor yellowColor];
  self.slider.translatesAutoresizingMaskIntoConstraints = NO;

  [self.toolbarView addSubview:self.playButton];
  [self.toolbarView addSubview:self.currTime];
  [self.toolbarView addSubview:self.totalTime];
  [self.toolbarView addSubview:self.slider];
  [self.controlView insertSubview:self.toolbarView atIndex:0];

  self.activityIndicator = [[UIActivityIndicatorView alloc]
                            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
  self.activityIndicator.hidesWhenStopped = YES;
  [self.controlView insertSubview:self.activityIndicator aboveSubview:self.toolbarView];

  // Layout.
  NSString *hlayout =
      @"|-[playButton(==40)]-5-[currTime(>=40)]-[slider(>=150)]-[totalTime(==currTime)]-|";
  NSString *vlayout =
      @"V:|[playButton(==40)]";
  self.viewsDictionary = @{ @"slider" : self.slider,
                            @"currTime" : self.currTime,
                            @"totalTime" :  self.totalTime,
                            @"playButton" : self.playButton
                            };
  [self.toolbarView addConstraints:
    [NSLayoutConstraint constraintsWithVisualFormat:hlayout
                                            options:NSLayoutFormatAlignAllCenterY
                                            metrics:nil views:self.viewsDictionary]];
  [self.toolbarView addConstraints:
   [NSLayoutConstraint constraintsWithVisualFormat:vlayout
                                           options:0
                                           metrics:nil views:self.viewsDictionary]];
}

/* Hide the tool bar, and the navigation controller if in the appropriate state. If there has been
 * a recent interaction, retry in kToolbarDelay seconds. */
- (void)hideToolBar {
  if (_state != LpvPlaying) {
    return;
  }
  if (self.recentInteraction) {
    self.recentInteraction = NO;
    [self performSelector:@selector(hideToolBar) withObject:self afterDelay:kToolbarDelay];
  } else  {
    [UIView animateWithDuration:0.5 animations:^{
      [self.toolbarView setAlpha:0];
    } completion:^(BOOL finished) {
      [self hideControls];
      [self.toolbarView setAlpha:1];
    }];
  }
}

/* Called when used touches the controlView. Display the controls, and if the user is playing
 * set a timeout to hide them again. */
- (void)didTouchControl:(id)sender {
  [self showControls];
  [self.controller hideNavigationBar:NO];
  self.recentInteraction = YES;
  if (_state == LpvPlaying) {
    [self performSelector:@selector(hideToolBar) withObject:self afterDelay:kToolbarDelay];
  }
}

/* Handle KVO for playback buffering */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
  if (!self.moviePlayer.currentItem || object != self.moviePlayer.currentItem) {
    return;
  }

  if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]) {
    [self.activityIndicator stopAnimating];
  } else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) {
    [self.activityIndicator startAnimating];
  }
}

@end
