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

#import "AppDelegate.h"
#import "CastViewController.h"
#import "ChromecastDeviceController.h"
#import "SimpleImageFetcher.h"
#import "TracksTableViewController.h"

#import <GoogleCast/GCKDevice.h>
#import <GoogleCast/GCKMediaControlChannel.h>
#import <GoogleCast/GCKMediaInformation.h>
#import <GoogleCast/GCKMediaMetadata.h>
#import <GoogleCast/GCKMediaStatus.h>

static NSString * const kListTracks = @"listTracks";
static NSString * const kListTracksPopover = @"listTracksPopover";
NSString * const kCastComponentPosterURL = @"castComponentPosterURL";

@interface CastViewController () <ChromecastDeviceControllerDelegate> {
  /* Flag to indicate we are scrubbing - the play position is only updated at the end. */
  BOOL _currentlyDraggingSlider;
  /* Flag to indicate whether we have status from the Cast device and can show the UI. */
  BOOL _readyToShowInterface;
  /* The most recent playback time - used for syncing between local and remote playback. */
  NSTimeInterval _lastKnownTime;
}

/* The device manager used for the currently casting media. */
@property(weak, nonatomic) ChromecastDeviceController *castDeviceController;
/* The image of the current media. */
@property IBOutlet UIImageView *thumbnailImage;
/* The label displaying the currently connected device. */
@property IBOutlet UILabel *castingToLabel;
/* The label displaying the currently playing media. */
@property(weak, nonatomic) IBOutlet UILabel *mediaTitleLabel;
/* An activity indicator while the cast is starting. */
@property(weak, nonatomic) IBOutlet UIActivityIndicatorView *castActivityIndicator;
/* A timer to trigger a callback to update the times/slider position. */
@property(weak, nonatomic) NSTimer *updateStreamTimer;
/* A timer to trigger removal of the volume control. */
@property(weak, nonatomic) NSTimer *fadeVolumeControlTimer;

/* The time of the play head in the current video. */
@property(nonatomic) UILabel *currTime;
/* The total time of the video. */
@property(nonatomic) UILabel *totalTime;
/* The tracks selector button (for closed captions primarily in this sample). */
@property(nonatomic) UIButton *cc;
/* The button that brings up the volume control: Apple recommends not overriding the hardware
   volume controls, so we use a separate on-screen UI. */
@property(nonatomic) UIButton *volumeButton;
/* The play icon button. */
@property(nonatomic) UIButton *playButton;
/* A slider for the progress/scrub bar. */
@property(nonatomic) UISlider *slider;
/* The next button. */
@property(nonatomic) UIButton *nextButton;
/* The previous button. */
@property(nonatomic) UIButton *previousButton;

/* A containing view for the toolbar. */
@property(nonatomic) UIView *toolbarView;
/* Views dictionary used for the visual format layout management. */
@property(nonatomic) NSDictionary *viewsDictionary;

/* Play image. */
@property(nonatomic) UIImage *playImage;
/* Pause image. */
@property(nonatomic) UIImage *pauseImage;

/* Whether the viewcontroller is currently visible. */
@property BOOL visible;

@end

@implementation CastViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  self.visible = false;

  self.castDeviceController = [ChromecastDeviceController sharedInstance];

  self.castingToLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Casting to %@", nil),
      _castDeviceController.deviceManager.device.friendlyName];

  self.volumeControlLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%@ Volume", nil),
                                    _castDeviceController.deviceManager.device.friendlyName];
  self.volumeSlider.minimumValue = 0;
  self.volumeSlider.maximumValue = 1.0;
  self.volumeSlider.value = _castDeviceController.deviceManager.deviceVolume ?
      _castDeviceController.deviceManager.deviceVolume : 0.5;
  self.volumeSlider.continuous = NO;
  [self.volumeSlider addTarget:self
                        action:@selector(sliderValueChanged:)
              forControlEvents:UIControlEventValueChanged];

  UIButton *transparencyButton = [[UIButton alloc] initWithFrame:self.view.bounds];
  transparencyButton.autoresizingMask =
      (UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight);
  transparencyButton.backgroundColor = [UIColor clearColor];
  [self.view insertSubview:transparencyButton aboveSubview:self.thumbnailImage];
  [transparencyButton addTarget:self
                         action:@selector(showVolumeSlider:)
               forControlEvents:UIControlEventTouchUpInside];
  self.navigationController.interactivePopGestureRecognizer.enabled = NO;
  [self initControls];
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  // Listen for volume change notifications.
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(volumeDidChange)
                                               name:@"castVolumeChanged"
                                             object:nil];

  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(didReceiveMediaStateChange)
                                               name:@"castMediaStatusChange"
                                             object:nil];

  // Add the cast icon to our nav bar.
  UIBarButtonItem *item = [[ChromecastDeviceController sharedInstance] queueItemForController:self];
  self.navigationItem.rightBarButtonItems = @[item];

  // Make the navigation bar transparent.
  self.navigationController.navigationBar.translucent = YES;
  [self.navigationController.navigationBar setBackgroundImage:[UIImage new]
                                                forBarMetrics:UIBarMetricsDefault];
  self.navigationController.navigationBar.shadowImage = [UIImage new];

  self.toolbarView.hidden = YES;
  [self.playButton setImage:self.playImage forState:UIControlStateNormal];

  [self resetInterfaceElements];

  _readyToShowInterface = (_castDeviceController.mediaInformation != nil);

  [self configureView];
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  self.visible = true;

  if (_castDeviceController.deviceManager.applicationConnectionState
      != GCKConnectionStateConnected) {
    // If we're not connected, exit.
    [self maybePopController];
  }

  // Assign ourselves as the delegate.
  _castDeviceController.delegate = self;
}

- (void)viewWillDisappear:(BOOL)animated {
  // I think we can safely stop the timer here
  [self.updateStreamTimer invalidate];
  self.updateStreamTimer = nil;

  // We no longer want to be delegate.
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [self.navigationController.navigationBar setBackgroundImage:nil
                                                forBarMetrics:UIBarMetricsDefault];
  [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
  self.visible = false;
  [super viewDidDisappear:animated];
}

- (IBAction)sliderValueChanged:(id)sender {
  UISlider *slider = (UISlider *)sender;
  NSLog(@"Got new slider value: %.2f", slider.value);
  [_castDeviceController.deviceManager setVolume:slider.value];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if (!_castDeviceController) {
    self.castDeviceController = [ChromecastDeviceController sharedInstance];
  }
  if ([segue.identifier isEqualToString:kListTracks] ||
      [segue.identifier isEqualToString:kListTracksPopover]) {
    GCKMediaInformation *media = _castDeviceController.mediaInformation;

    UITabBarController *controller;
    controller = (UITabBarController *)
        ((UINavigationController *)segue.destinationViewController).visibleViewController;
    TracksTableViewController *trackController = controller.viewControllers[0];
    [trackController setMedia:media
                      forType:GCKMediaTrackTypeText
             deviceController:_castDeviceController.mediaControlChannel];
    TracksTableViewController *audioTrackController = controller.viewControllers[1];
    [audioTrackController setMedia:media
                           forType:GCKMediaTrackTypeAudio
                  deviceController:_castDeviceController.mediaControlChannel];
  }
}

- (IBAction)unwindToCastView:(UIStoryboardSegue *)segue; {
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    [self dismissViewControllerAnimated:YES completion:nil];
  }
}

- (void)maybePopController {
  // Only take action if we're visible.
  if (self.visible) {
    [self.navigationController popViewControllerAnimated:YES];
  }
}

#pragma mark - Managing the detail item

- (void)resetInterfaceElements {
  self.totalTime.text = @"";
  self.currTime.text = @"";
  [self.slider setValue:0];
  [self.castActivityIndicator startAnimating];
  _currentlyDraggingSlider = NO;
  self.toolbarView.hidden = YES;
  _readyToShowInterface = NO;
}

- (IBAction)showVolumeSlider:(id)sender {
  if (self.volumeControls.hidden) {
    self.volumeControls.hidden = NO;
    [self.volumeControls setAlpha:0];

    [UIView animateWithDuration:0.5
                     animations:^{
                       self.volumeControls.alpha = 1.0;
                     }
                     completion:^(BOOL finished){
                       NSLog(@"Volume slider hidden done!");
                     }];

  }
  // Do this so if a user taps the screen or plays with the volume slider, it resets the timer
  // for fading the volume controls
  if (self.fadeVolumeControlTimer != nil) {
    [self.fadeVolumeControlTimer invalidate];
  }
  self.fadeVolumeControlTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                                 target:self
                                                               selector:@selector(fadeVolumeSlider:)
                                                               userInfo:nil
                                                                repeats:NO];
}

- (void)fadeVolumeSlider:(NSTimer *)timer {
  [self.volumeControls setAlpha:1.0];

  [UIView animateWithDuration:0.5
                   animations:^{
                     self.volumeControls.alpha = 0.0;
                   }
                   completion:^(BOOL finished){
                     self.volumeControls.hidden = YES;
                   }];
}


- (void)updateInterfaceFromCast:(NSTimer *)timer {
  if (!_readyToShowInterface) {
    return;
  }

  if (_castDeviceController.playerState != GCKMediaPlayerStateBuffering) {
    [self.castActivityIndicator stopAnimating];
  } else {
    [self.castActivityIndicator startAnimating];
  }

  if (_castDeviceController.streamDuration > 0 && !_currentlyDraggingSlider) {
    _lastKnownTime = _castDeviceController.streamPosition;
    self.currTime.text = [self getFormattedTime:_castDeviceController.streamPosition];
    self.totalTime.text = [self getFormattedTime:_castDeviceController.streamDuration];
    [self.slider
        setValue:(_castDeviceController.streamPosition / _castDeviceController.streamDuration)
        animated:YES];
  }
  [self updateToolbarControls];
}


- (void)updateToolbarControls {
  if (_castDeviceController.playerState == GCKMediaPlayerStatePaused ||
      _castDeviceController.playerState == GCKMediaPlayerStateIdle) {
    [self.playButton setImage:self.playImage forState:UIControlStateNormal];
  } else if (_castDeviceController.playerState == GCKMediaPlayerStatePlaying ||
      _castDeviceController.playerState == GCKMediaPlayerStateBuffering) {
    [self.playButton setImage:self.pauseImage forState:UIControlStateNormal];
  }
}

// Little formatting option here
- (NSString *)getFormattedTime:(NSTimeInterval)timeInSeconds {
  int seconds = round(timeInSeconds);
  int hours = seconds / (60 * 60);
  seconds %= (60 * 60);

  int minutes = seconds / 60;
  seconds %= 60;

  if (hours > 0) {
    return [NSString stringWithFormat:@"%d:%02d:%02d", hours, minutes, seconds];
  } else {
    return [NSString stringWithFormat:@"%d:%02d", minutes, seconds];
  }
}

- (void)configureView {
  GCKMediaInformation *media = _castDeviceController.mediaInformation;
  BOOL connected =
      _castDeviceController.deviceManager.applicationConnectionState == GCKConnectionStateConnected;
  if (!media || !connected) {
    [self resetInterfaceElements];
    return;
  }

  self.toolbarView.hidden = NO;

  NSString *title = [media.metadata stringForKey:kGCKMetadataKeyTitle];
  // TODO(i18n): Localize this string.
  self.castingToLabel.text =
      [NSString stringWithFormat:@"Casting to %@",
          _castDeviceController.deviceManager.device.friendlyName];
  self.mediaTitleLabel.text = title;

  NSLog(@"Configured view with media: %@", media);

  // Loading thumbnail async.
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSString *posterURL = [media.metadata stringForKey:kCastComponentPosterURL];
    if (posterURL) {
      UIImage *image = [UIImage
          imageWithData:[SimpleImageFetcher getDataFromImageURL:[NSURL URLWithString:posterURL]]];

      dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Loaded thumbnail image");
        self.thumbnailImage.image = image;
        [self.view setNeedsLayout];
      });
    }
  });

  self.cc.enabled = media.mediaTracks.count > 0;

  // Dance to find our position in the queue, and enable/disable buttons
  // as required.
  GCKMediaStatus *mediaStatus = _castDeviceController.mediaControlChannel.mediaStatus;
  GCKMediaQueueItem *currentItem = [mediaStatus queueItemWithItemID:mediaStatus.currentItemID];
  BOOL hasPrevious = YES;
  BOOL hasNext = NO;
  NSInteger count = [mediaStatus queueItemCount];
  for (NSInteger i = 0; i < count; ++i) {
    GCKMediaQueueItem *item = [mediaStatus queueItemAtIndex:i];
    if (currentItem == item) {
      hasPrevious = (i > 0);
      hasNext = (i < count - 1);
    }
  }
  self.nextButton.enabled = hasNext;
  self.previousButton.enabled = hasPrevious;

  // Start the timer
  if (self.updateStreamTimer) {
    [self.updateStreamTimer invalidate];
    self.updateStreamTimer = nil;
  }

  self.updateStreamTimer =
      [NSTimer scheduledTimerWithTimeInterval:1.0
                                       target:self
                                     selector:@selector(updateInterfaceFromCast:)
                                     userInfo:nil
                                      repeats:YES];
}

#pragma mark - Interface

- (IBAction)previousButtonClicked:(id)sender {
  [_castDeviceController.mediaControlChannel queuePreviousItem];
}

- (IBAction)nextButtonClicked:(id)sender {
  [_castDeviceController.mediaControlChannel queueNextItem];
}

- (IBAction)playButtonClicked:(id)sender {
  if (_castDeviceController.playerState == GCKMediaPlayerStatePaused) {
    [_castDeviceController.mediaControlChannel play];
  } else {
    [_castDeviceController.mediaControlChannel pause];
  }
}

- (IBAction)subtitleButtonClicked:(id)sender {
  if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
    [self performSegueWithIdentifier:kListTracksPopover sender:self];
  } else {
    [self performSegueWithIdentifier:kListTracks sender:self];
  }
}

- (IBAction)onTouchDown:(id)sender {
  _currentlyDraggingSlider = YES;
}

// This is continuous, so we can update the current/end time labels
- (IBAction)onSliderValueChanged:(id)sender {
  float pctThrough = [self.slider value];
  if (_castDeviceController.streamDuration > 0) {
    self.currTime.text =
        [self getFormattedTime:(pctThrough * _castDeviceController.streamDuration)];
  }
}

// This is called only on one of the two touch up events
- (void)touchIsFinished {
  [_castDeviceController setPlaybackPercent:[self.slider value]];
  _currentlyDraggingSlider = NO;
}

- (IBAction)onTouchUpInside:(id)sender {
  NSLog(@"Touch up inside");
  [self touchIsFinished];

}
- (IBAction)onTouchUpOutside:(id)sender {
  NSLog(@"Touch up outside");
  [self touchIsFinished];
}

#pragma mark - ChromecastControllerDelegate

/**
 * Called when connection to the device was closed.
 */
- (void)didDisconnect {
  [self maybePopController];
}

/**
 * Called when the playback state of media on the device changes.
 */
- (void)didReceiveMediaStateChange {
  // TODO: This fires when the media just changes, e.g. play/next buttons, or natural flow. Ignore for now?
//  GCKMediaInformation *media = _castDeviceController.mediaInformation;
//  if (_castDeviceController.playerState == GCKMediaPlayerStateIdle || !media) {
//    [self maybePopController];
//    return;
//  }

  _readyToShowInterface = YES;
  if ([self isViewLoaded] && self.view.window) {
    // Display toolbar if we are current view.
    self.toolbarView.hidden = NO;
    [self configureView];
  }
}

#pragma mark - implementation.

- (void)initControls {

  // Play/Pause images.
  self.playImage = [UIImage imageNamed:@"media_play"];
  self.pauseImage = [UIImage imageNamed:@"media_pause"];

  // Toolbar. Double the size of the iOS standard.
  CGRect toolbarFrame = self.navigationController.toolbar.frame;
  toolbarFrame.origin.x = (toolbarFrame.origin.x + toolbarFrame.size.height - 80);
  toolbarFrame.size.height = 120;

  self.toolbarView = [[UIView alloc] initWithFrame:toolbarFrame];
  self.toolbarView.translatesAutoresizingMaskIntoConstraints = NO;
  // Hide the nav controller toolbar - we are managing our own to get autolayout.
  self.navigationController.toolbarHidden = YES;

  // Next/Previous buttons.
  self.nextButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.nextButton setImage:[UIImage imageNamed:@"media_right"] forState:UIControlStateNormal];
  self.nextButton.tintColor = [UIColor whiteColor];
  [self.nextButton addTarget:self
                      action:@selector(nextButtonClicked:)
            forControlEvents:UIControlEventTouchUpInside];
  self.previousButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.previousButton setImage:[UIImage imageNamed:@"media_left"] forState:UIControlStateNormal];
  self.previousButton.tintColor = [UIColor whiteColor];
  [self.previousButton addTarget:self
                          action:@selector(previousButtonClicked:)
                forControlEvents:UIControlEventTouchUpInside];

  // TODO: Control buttons with proper constraints.
  [self.nextButton setFrame:CGRectMake(40, 40, 40, 40)];
  [self.toolbarView addSubview:self.nextButton];
  [self.previousButton setFrame:CGRectMake(0, 40, 40, 40)];
  [self.toolbarView addSubview:self.previousButton];

  // Play/Pause button.
  self.playButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.playButton setFrame:CGRectMake(0, 0, 40, 40)];
  if (_castDeviceController.playerState == GCKMediaPlayerStatePaused) {
    [self.playButton setImage:self.playImage forState:UIControlStateNormal];
  } else {
    [self.playButton setImage:self.pauseImage forState:UIControlStateNormal];
  }
  [self.playButton addTarget:self
                      action:@selector(playButtonClicked:)
            forControlEvents:UIControlEventTouchUpInside];
  self.playButton.tintColor = [UIColor whiteColor];
  NSLayoutConstraint *constraint =[NSLayoutConstraint constraintWithItem:self.playButton
                                                               attribute:NSLayoutAttributeHeight
                                                               relatedBy:NSLayoutRelationEqual
                                                                  toItem:self.playButton
                                                               attribute:NSLayoutAttributeWidth
                                                              multiplier:1.0
                                                                constant:0.0f];
  [self.playButton addConstraint:constraint];
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

  // Volume control.
  self.volumeButton = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.volumeButton setFrame:CGRectMake(0, 0, 40, 40)];
  [self.volumeButton setImage:[UIImage imageNamed:@"icon_volume3"] forState:UIControlStateNormal];
  [self.volumeButton addTarget:self
                        action:@selector(showVolumeSlider:)
              forControlEvents:UIControlEventTouchUpInside];
  self.volumeButton.tintColor = [UIColor whiteColor];
  constraint =[NSLayoutConstraint constraintWithItem:self.volumeButton
                                           attribute:NSLayoutAttributeHeight
                                           relatedBy:NSLayoutRelationEqual
                                              toItem:self.volumeButton
                                           attribute:NSLayoutAttributeWidth
                                          multiplier:1.0
                                            constant:0.0f];
  [self.volumeButton addConstraint:constraint];
  self.volumeButton.translatesAutoresizingMaskIntoConstraints = NO;

  // Tracks selector.
  self.cc = [UIButton buttonWithType:UIButtonTypeSystem];
  [self.cc setFrame:CGRectMake(0, 0, 40, 40)];
  [self.cc setImage:[UIImage imageNamed:@"closed_caption_white.png.png"]
                               forState:UIControlStateNormal];
  [self.cc addTarget:self
                        action:@selector(subtitleButtonClicked:)
              forControlEvents:UIControlEventTouchUpInside];
  self.cc.tintColor = [UIColor whiteColor];
  constraint =[NSLayoutConstraint constraintWithItem:self.cc
                                           attribute:NSLayoutAttributeHeight
                                           relatedBy:NSLayoutRelationEqual
                                              toItem:self.cc
                                           attribute:NSLayoutAttributeWidth
                                          multiplier:1.0
                                            constant:0.0f];
  [self.cc addConstraint:constraint];
  self.cc.translatesAutoresizingMaskIntoConstraints = NO;

  // Slider.
  self.slider = [[UISlider alloc] init];
  UIImage *thumb = [UIImage imageNamed:@"thumb.png"];
  [self.slider setThumbImage:thumb forState:UIControlStateNormal];
  [self.slider setThumbImage:thumb forState:UIControlStateHighlighted];
  [self.slider addTarget:self
                  action:@selector(onSliderValueChanged:)
        forControlEvents:UIControlEventValueChanged];
  [self.slider addTarget:self
                  action:@selector(onTouchDown:)
        forControlEvents:UIControlEventTouchDown];
  [self.slider addTarget:self
                  action:@selector(onTouchUpInside:)
        forControlEvents:UIControlEventTouchUpInside];
  [self.slider addTarget:self
                  action:@selector(onTouchUpOutside:)
        forControlEvents:UIControlEventTouchCancel];
  [self.slider addTarget:self
                  action:@selector(onTouchUpOutside:)
        forControlEvents:UIControlEventTouchUpOutside];
  self.slider.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  self.slider.minimumValue = 0;
  self.slider.minimumTrackTintColor = [UIColor yellowColor];
  self.slider.translatesAutoresizingMaskIntoConstraints = NO;

  [self.view addSubview:self.toolbarView];
  [self.toolbarView addSubview:self.playButton];
  [self.toolbarView addSubview:self.volumeButton];
  [self.toolbarView addSubview:self.currTime];
  [self.toolbarView addSubview:self.slider];
  [self.toolbarView addSubview:self.totalTime];
  [self.toolbarView addSubview:self.cc];

  // Round the corners on the volume pop up.
  self.volumeControls.layer.cornerRadius = 5;
  self.volumeControls.layer.masksToBounds = YES;

  // Layout.
  NSString *hlayout = [NSString stringWithFormat:@"%@%@",
      @"|-(<=5)-[playButton(==35)]-[volumeButton(==30)]-[currTime]",
      @"-[slider(>=90)]-[totalTime]-[ccButton(==playButton)]-(<=5)-|"];
  self.viewsDictionary = @{ @"slider" : self.slider,
                            @"currTime" : self.currTime,
                            @"totalTime" :  self.totalTime,
                            @"playButton" : self.playButton,
                            @"volumeButton" : self.volumeButton,
                            @"ccButton" : self.cc
                            };
  [self.toolbarView addConstraints:
   [NSLayoutConstraint constraintsWithVisualFormat:hlayout
                                           options:NSLayoutFormatAlignAllCenterY
                                           metrics:nil
                                             views:self.viewsDictionary]];

  NSString *vlayout = @"V:[slider(==35)]-|";
  [self.toolbarView addConstraints:
   [NSLayoutConstraint constraintsWithVisualFormat:vlayout
                                           options:0
                                           metrics:nil
                                             views:self.viewsDictionary]];

  // Autolayout toolbar.
  NSString *toolbarVLayout = @"V:[toolbar(==120)]|";
  NSString *toolbarHLayout = @"|[toolbar]|";
  [self.view addConstraints:
   [NSLayoutConstraint constraintsWithVisualFormat:toolbarVLayout
                                           options:0
                                           metrics:nil
                                             views:@{@"toolbar" : self.toolbarView}]];
  [self.view addConstraints:
   [NSLayoutConstraint constraintsWithVisualFormat:toolbarHLayout
                                           options:0
                                           metrics:nil
                                             views:@{@"toolbar" : self.toolbarView}]];
}

#pragma mark Volume listener.

- (void)volumeDidChange {
  self.volumeSlider.value = _castDeviceController.deviceManager.deviceVolume;
}

@end