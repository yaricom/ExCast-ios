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
#import "LocalPlayerViewController.h"
#import "CastViewController.h"
#import "SimpleImageFetcher.h"
#import "CastInstructionsViewController.h"

#define MOVIE_CONTAINER_TAG 1

static NSString *kCastSegueIdentifier = @"castMedia";

@interface LocalPlayerViewController () {
  NSTimeInterval _lastKnownPlaybackTime;
  BOOL _goToMiniControllerCast;
  __weak IBOutlet UIImageView *_thumbnailView;
  __weak ChromecastDeviceController *_chromecastController;
}
@property(weak, nonatomic) IBOutlet UIButton *playPauseButton;

@property MPMoviePlayerController *moviePlayer;

@end

@implementation LocalPlayerViewController

#pragma mark State management

// Retrieve the current media based on the central MediaList and the currently
// playing media metadata.
- (Media *)currentlyPlayingMedia {
  AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
  NSString *title =
    [_chromecastController.mediaInformation.metadata stringForKey:kGCKMetadataKeyTitle];
  int index = [delegate.mediaList indexOfMediaByTitle:title];
  if (index >= 0) {
    return [delegate.mediaList mediaAtIndex:index];
  }
  return nil;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([[segue identifier] isEqualToString:kCastSegueIdentifier]) {
    if ( _goToMiniControllerCast) {
      _goToMiniControllerCast = NO;
      [(CastViewController *)[segue destinationViewController]
          setMediaToPlay:[self currentlyPlayingMedia]];
    } else {
      [(CastViewController *)[segue destinationViewController]
          setMediaToPlay:self.mediaToPlay
        withStartingTime:_lastKnownPlaybackTime];
      [(CastViewController *)[segue destinationViewController] setLocalPlayer:self];
    }
  }
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
  if ([identifier isEqualToString:kCastSegueIdentifier]) {
    if (_goToMiniControllerCast) {
      if (![self currentlyPlayingMedia]) {
        // If we don't have media to cast, don't allow the segue.
        return NO;
      }
    }
  }
  return YES;

}

- (IBAction)playPauseButtonPressed:(id)sender {
  if (_chromecastController.isConnected) {
    if (self.playPauseButton.selected == NO) {
      [_chromecastController pauseCastMedia:NO];
    }
    [self performSegueWithIdentifier:kCastSegueIdentifier sender:self];
  } else {
    [self playMovieIfExists];
  }
}

#pragma mark - Managing the detail item

- (void)setMediaToPlay:(id)newMediaToPlay {
  if (_mediaToPlay != newMediaToPlay) {
    _mediaToPlay = newMediaToPlay;
  }
}

- (void)moviePlayBackDidChange:(NSNotification *)notification {
  NSLog(@"Movie playback state did change %d",(int) _moviePlayer.playbackState);
}

- (void)moviePlayBackDidFinish:(NSNotification *)notification {
  NSLog(@"Looks like playback is over.");
  int reason = [[[notification userInfo]
      valueForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey] intValue];
  if (reason == MPMovieFinishReasonPlaybackEnded) {
    NSLog(@"Playback has ended normally!");
  }
}

// Asynchronously load the table view image.
- (void)loadMovieImage {
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

  dispatch_async(queue, ^{
    UIImage *image = [UIImage
                      imageWithData:[SimpleImageFetcher getDataFromImageURL:self.mediaToPlay.thumbnailURL]];

    dispatch_sync(dispatch_get_main_queue(), ^{
      _thumbnailView.image = image;
      [_thumbnailView setNeedsLayout];
    });
  });
}

- (void)playMovieIfExists {
  if (self.mediaToPlay) {
    if (_chromecastController.isConnected) {
      [self loadMovieImage];
    } else {
      // We are playing locally, so remove any existing session information.
      [_chromecastController clearPreviousSession];
      NSURL *url = self.mediaToPlay.URL;
      NSLog(@"Playing movie %@", url);
      self.moviePlayer.contentURL = url;
      self.moviePlayer.allowsAirPlay = YES;
      self.moviePlayer.controlStyle = MPMovieControlStyleEmbedded;
      self.moviePlayer.repeatMode = MPMovieRepeatModeNone;
      self.moviePlayer.scalingMode = MPMovieScalingModeAspectFit;
      self.moviePlayer.shouldAutoplay = YES;

      UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
      if (UIInterfaceOrientationIsLandscape(orientation) &&
          [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.moviePlayer.fullscreen = YES;
      } else {
        self.moviePlayer.fullscreen = NO;
      }

      [self.moviePlayer prepareToPlay];
      [self.moviePlayer play];
    }
    self.moviePlayer.view.hidden = _chromecastController.isConnected;

    self.mediaTitle.text = self.mediaToPlay.title;
    self.mediaSubtitle.text = self.mediaToPlay.subtitle;
    self.mediaDescription.text = self.mediaToPlay.descrip;
  }
}

- (void)createMoviePlayer {
  //Create movie player controller and add it to the view
  if (!self.moviePlayer) {
    // Next create the movie player, on top of the thumbnail view.
    self.moviePlayer = [[MPMoviePlayerController alloc] init];
    self.moviePlayer.view.frame = _thumbnailView.frame;
    //self.moviePlayer.view.hidden = _chromecastController.isConnected;
    self.moviePlayer.view.hidden = YES;
    [self.view addSubview:self.moviePlayer.view];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackDidFinish:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification
                                               object:self.moviePlayer];

    [[NSNotificationCenter defaultCenter]
        addObserver:self
           selector:@selector(moviePlayBackDidChange:)
               name:MPMoviePlayerPlaybackStateDidChangeNotification
             object:self.moviePlayer];
  }
  if (!_thumbnailView.image) {
    [self loadMovieImage];
  }
}

- (void)viewDidLoad {
  [super viewDidLoad];

  // Store a reference to the chromecast controller.
  AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
  _chromecastController = delegate.chromecastDeviceController;

  //Add cast button
  if (_chromecastController.deviceScanner.devices.count > 0) {
    [self showCastIcon];
  }

  // Set an empty image for selected ("pause") state.
  [self.playPauseButton setImage:[UIImage new] forState:UIControlStateSelected];

  [self createMoviePlayer];

  // Listen to orientation changes.
  [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(deviceOrientationDidChange:)
                                               name:UIDeviceOrientationDidChangeNotification
                                             object:nil];

  // Aspect scale the image, and clip it to the view bounds.
  _thumbnailView.contentMode = UIViewContentModeScaleAspectFill;
  _thumbnailView.clipsToBounds = YES;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  // Assign ourselves as delegate ONLY in viewWillAppear of a view controller.
  _chromecastController.delegate = self;
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  if (!_thumbnailView.image) {
    [self loadMovieImage];
  }
  // Hide the player, unless it is paused.
  if (self.moviePlayer && self.moviePlayer.playbackState == MPMoviePlaybackStateStopped) {
    self.moviePlayer.view.frame = _thumbnailView.frame;
    self.moviePlayer.view.hidden = YES;
  }
  [self updateControls];
}

- (void)viewDidDisappear:(BOOL)animated {
  [super viewDidDisappear:animated];
  // TODO Pause the player if navigating to a different view other than fullscreen movie view.
  if (self.moviePlayer && self.moviePlayer.fullscreen == NO) {
    [self.moviePlayer pause];
  }
}

- (void)deviceOrientationDidChange:(NSNotification *)notification {
  // Respond to orientation only when not connected.
  if (_chromecastController.isConnected == YES) {
    return;
  }
  //Obtaining the current device orientation
  UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
  if (self.moviePlayer.playbackState != MPMoviePlaybackStateStopped) {
    if (UIInterfaceOrientationIsLandscape(orientation)) {
      [self.moviePlayer setFullscreen:YES animated:YES];
    } else {
      [self.moviePlayer setFullscreen:NO animated:YES];
    }
  } else if (self.moviePlayer) {
    self.moviePlayer.view.frame = _thumbnailView.frame;
  }
}

#pragma mark - RemotePlayerDelegate

- (void)setLastKnownDuration: (NSTimeInterval)time {
  if (time > 0) {
    _lastKnownPlaybackTime = time;
  }
}

#pragma mark - ChromecastControllerDelegate

- (void)didDiscoverDeviceOnNetwork {
  // Add the chromecast icon if not present.
  [self showCastIcon];
}

/**
 * Called when connection to the device was established.
 *
 * @param device The device to which the connection was established.
 */
- (void)didConnectToDevice:(GCKDevice *)device {
  if (self.moviePlayer.playbackState == MPMoviePlaybackStatePlaying ||
        self.moviePlayer.playbackState == MPMoviePlaybackStatePaused ) {
    if (_lastKnownPlaybackTime == 0 && [self.moviePlayer currentPlaybackTime] != NAN) {
      _lastKnownPlaybackTime = [self.moviePlayer currentPlaybackTime];
    }
    [self.moviePlayer stop];
    [self performSegueWithIdentifier:kCastSegueIdentifier sender:self];
  }
}

/**
 * Called when connection to the device was closed.
 */
- (void)didDisconnect {
  [self updateControls];
}

/**
 * Called when the playback state of media on the device changes.
 */
- (void)didReceiveMediaStateChange {
  [self updateControls];
}

/**
 * Called to display the modal device view controller from the cast icon.
 */
- (void)shouldDisplayModalDeviceController {
  [self performSegueWithIdentifier:@"listDevices" sender:self];
}

/**
 * Called to display the remote media playback view controller.
 */
- (void)shouldPresentPlaybackController {
  _goToMiniControllerCast = YES;
  [self performSegueWithIdentifier:kCastSegueIdentifier sender:self];
}

#pragma mark - Showing the overlay

// Show cast icon. If this is the first time the cast icon is appearing, show an overlay with
// instructions highlighting the cast icon.
- (void)showCastIcon {
  self.navigationItem.rightBarButtonItem = _chromecastController.chromecastBarButton;
  [CastInstructionsViewController showIfFirstTimeOverViewController:self];
}

#pragma mark - Implementation

- (void)updateControls {
  // Check if the selected media is also playing on the screen. If so display the pause button.
  NSString *title =
      [_chromecastController.mediaInformation.metadata stringForKey:kGCKMetadataKeyTitle];
  self.playPauseButton.selected = (_chromecastController.isConnected &&
      ([title isEqualToString:self.mediaToPlay.title] &&
       (_chromecastController.playerState == GCKMediaPlayerStatePlaying ||
        _chromecastController.playerState == GCKMediaPlayerStateBuffering)));
  self.playPauseButton.highlighted = NO;

  [_chromecastController updateToolbarForViewController:self];
}
@end