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
#import "CastInstructionsViewController.h"

#import "LocalPlayerViewController.h"

static NSString *kCastSegueIdentifier = @"castMedia";
static NSString *kCastSegueListDevices = @"listDevices";

@interface LocalPlayerViewController () {
  /* The latest playback time sourced either from local player or the Cast metadata. */
  NSTimeInterval _lastKnownPlaybackTime;
  /* Whether we want to go to the media defined in this controller or the mini controller. */
  BOOL _goToMiniControllerCast;
  /* Whether to reset the edges on disappearing. */
  BOOL _resetEdgesOnDisappear;
  /* Reference to our main Cast managment class. */
  __weak ChromecastDeviceController *_chromecastController;
}

@end

@implementation LocalPlayerViewController

#pragma mark State management

/* Retrieve the current media based on the central MediaList as the currently 
 * playing media metadata. */
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

/* Configure the CastViewController if we are casting a video. */
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:kCastSegueIdentifier]) {
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

#pragma mark - Managing the detail item

- (void)setMediaToPlay:(id)newMediaToPlay {
  if (_mediaToPlay != newMediaToPlay) {
    _mediaToPlay = newMediaToPlay;
    [self syncTextToMedia];
  }
}

- (void)syncTextToMedia {
  self.mediaTitle.text = self.mediaToPlay.title;
  self.mediaSubtitle.text = self.mediaToPlay.subtitle;
  self.mediaDescription.text = self.mediaToPlay.descrip;
}

#pragma mark - ViewController lifecycle

- (void)viewDidLoad {
  [super viewDidLoad];

  // Store a reference to the chromecast controller.
  AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
  _chromecastController = delegate.chromecastDeviceController;

  //Add cast button
  if (_chromecastController.deviceScanner.devices.count > 0) {
    [self showCastIcon];
  }
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];
  [self.playerView setMedia:_mediaToPlay];
  _resetEdgesOnDisappear = YES;

  // Listen to orientation changes.
  [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(deviceOrientationDidChange:)
                                               name:UIDeviceOrientationDidChangeNotification
                                             object:nil];

  // Assign ourselves as delegate ONLY in viewWillAppear of a view controller.
  _chromecastController.delegate = self;
  _playerView.controller = self;
  [self syncTextToMedia];
  if (self.playerView.fullscreen) {
    [self hideNavigationBar:YES];
  }
}

- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  // Do the control update in a separate runloop to ensure we don't bounce any toolbar.s
  [self performSelector:@selector(updateControls) withObject:self afterDelay:0];
}

- (void)viewWillDisappear:(BOOL)animated {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  if (_playerView.playingLocally) {
    [_playerView pause];
  }
  if (_resetEdgesOnDisappear) {
    [self setNavigationBarStyle:LPVNavBarDefault];
  }
  [super viewWillDisappear:animated];
}

- (void)deviceOrientationDidChange:(NSNotification *)notification {
  // Respond to orientation only when not connected.
  if (_chromecastController.isConnected == YES) {
    return;
  }

  [self.playerView orientationChanged];

  UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
  if (!UIInterfaceOrientationIsLandscape(orientation) || !self.playerView.playingLocally) {
    [self setNavigationBarStyle:LPVNavBarDefault];
  }
}

#pragma mark - LocalPlayerController

/* Play has been pressed in the LocalPlayerView. */
- (void)didTapPlayForCast {
  [self performSegueWithIdentifier:kCastSegueIdentifier sender:self];
}

/* Pause has beeen pressed in the LocalPlayerView. */
- (void)didTapPauseForCast {
  [_chromecastController pauseCastMedia:YES];
  _goToMiniControllerCast = YES;
  [self performSegueWithIdentifier:kCastSegueIdentifier sender:self];
}

/* Signal the requested style for the view. */
- (void)setNavigationBarStyle:(LPVNavBarStyle)style {
  if (style == LPVNavBarDefault) {
    self.edgesForExtendedLayout = UIRectEdgeAll;
    [self hideNavigationBar:NO];
    [self.navigationController.navigationBar setBackgroundImage:nil
                                                  forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = nil;
    [[UIApplication sharedApplication] setStatusBarHidden:NO
                                            withAnimation:UIStatusBarAnimationFade];
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
    _resetEdgesOnDisappear = NO;
  } else if(style == LPVNavBarTransparent) {
    self.edgesForExtendedLayout = UIRectEdgeNone;
    [self.navigationController.navigationBar setBackgroundImage:[UIImage new]
                                                  forBarMetrics:UIBarMetricsDefault];
    self.navigationController.navigationBar.shadowImage = [UIImage new];
    [[UIApplication sharedApplication] setStatusBarHidden:YES
                                            withAnimation:UIStatusBarAnimationFade];
    // Disable the swipe gesture if we're fullscreen.
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    _resetEdgesOnDisappear = YES;
  }
}

/* Prefer hiding the status bar if we're full screen. */
- (BOOL)prefersStatusBarHidden {
  return self.playerView.fullscreen;
}

/* Request the navigation bar to be hidden or shown. */
- (void)hideNavigationBar:(BOOL)hide {
  [self.navigationController.navigationBar setHidden:hide];
}


#pragma mark - RemotePlayerDelegate

/* Update the local time from the Cast played time. */
- (void)setLastKnownDuration: (NSTimeInterval)time {
  if (time > 0) {
    _lastKnownPlaybackTime = time;
  }
}

#pragma mark - ChromecastControllerDelegate

/* Trigger the icon to appear if a device is discovered. */
- (void)didDiscoverDeviceOnNetwork {
  [self showCastIcon];
}

/**
 * Called when connection to the device was established.
 *
 * @param device The device to which the connection was established.
 */
- (void)didConnectToDevice:(GCKDevice *)device {
  if (_playerView.playingLocally) {
    [_playerView pause];
    _playerView.castMode = LPVCastPlaying;
    if (_lastKnownPlaybackTime == 0 && _playerView.playbackTime) {
      _lastKnownPlaybackTime = _playerView.playbackTime;
    }
    [self performSegueWithIdentifier:kCastSegueIdentifier sender:self];
  } else {
    _playerView.castMode = LPVCastConnected;
  }
}

/**
 * Called when connection to the device was closed.
 */
- (void)didDisconnect {
  if (_lastKnownPlaybackTime) {
    self.playerView.playbackTime = _lastKnownPlaybackTime;
  }
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
  [self.playerView pause];
  _resetEdgesOnDisappear = NO;
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

/* Show cast icon. If this is the first time the cast icon is appearing, show an overlay with
 * instructions highlighting the cast icon. */
- (void)showCastIcon {
  self.navigationItem.rightBarButtonItem = _chromecastController.chromecastBarButton;
  [self updateControls];
  [self hideNavigationBar:NO]; // Display the nav bar in case the cling is needed.
  _resetEdgesOnDisappear = NO;
  [CastInstructionsViewController showIfFirstTimeOverViewController:self];
}

#pragma mark - Control management.

/* Set the state for the LocalPlayerView based on the state of the Cast device. */
- (void)updateControls {
  NSString *title =
      [_chromecastController.mediaInformation.metadata stringForKey:kGCKMetadataKeyTitle];
  if (_chromecastController.isConnected) {
      if ([title isEqualToString:self.mediaToPlay.title] &&
       (_chromecastController.playerState == GCKMediaPlayerStatePlaying ||
        _chromecastController.playerState == GCKMediaPlayerStateBuffering)) {
         _playerView.castMode = LPVCastPlaying;
       } else {
         _playerView.castMode = LPVCastConnected;
       }
  } else if (_chromecastController.deviceScanner.devices.count > 0) {
    _playerView.castMode = LPVCastAvailable;
  } else {
    _playerView.castMode = LPVCastUnavailable;
  }

  [_chromecastController updateToolbarForViewController:self];
}

@end