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
#import "CastInstructionsViewController.h"
#import "CastViewController.h"
#import "CastDeviceController.h"
#import "GCKMediaInformation+LocalMedia.h"
#import "LocalPlayerViewController.h"
#import "NotificationConstants.h"
#import "AlertHelper.h"

#import "ExMedia.h"

#import <GoogleCast/GoogleCast.h>

@interface LocalPlayerViewController () <CastDeviceControllerDelegate>

/* Whether to reset the edges on disappearing. */
@property(nonatomic) BOOL resetEdgesOnDisappear;

/** The queue button. */
@property(nonatomic, strong) UIBarButtonItem *showQueueButton;
@property(nonatomic, assign) BOOL playbackEnabled;

@end

@implementation LocalPlayerViewController

#pragma mark - ViewController lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create the queue button.
    UIImage *playlistImage = [UIImage imageNamed:@"playlist_white.png"];
    _showQueueButton = [[UIBarButtonItem alloc] initWithImage:playlistImage
                                                        style:UIBarButtonItemStylePlain
                                                       target:self
                                                       action:@selector(showQueue:)];
    
    // hide toolbar
    self.navigationController.toolbarHidden = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.playerView setMedia:_mediaToPlay];
    [self.playerView playbackEnabled:self.playbackEnabled];
    _resetEdgesOnDisappear = YES;
    
    // Listen to orientation changes.
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(deviceOrientationDidChange:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    _playerView.delegate = self;
    [self syncTextToMedia];
    if (self.playerView.fullscreen) {
        [self hideNavigationBar:YES];
    }
    
    // Assign ourselves as delegate ONLY in viewWillAppear of a view controller.
    CastDeviceController *controller = [CastDeviceController sharedInstance];
    controller.delegate = self;
    UIBarButtonItem *item = [controller queueItemForController:self];
    self.navigationItem.rightBarButtonItems = @[item];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateQueueButton)
                                                 name:kCastQueueUpdatedNotification
                                               object:nil];
    [self updateQueueButton];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_playerView.playingLocally) {
        [_playerView pause];
    }
    
    if (_resetEdgesOnDisappear) {
        [self setNavigationBarStyle:LPVNavBarDefault];
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super viewWillDisappear:animated];
}

- (void)dealloc {
    // Explicitly clear the playing media and release the AVPlayer.
    [_playerView setMedia:nil];
    _playerView.delegate = nil;
}

- (void)deviceOrientationDidChange:(NSNotification *)notification {
    [self.playerView orientationChanged];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (!UIInterfaceOrientationIsLandscape(orientation) || !self.playerView.playingLocally) {
        [self setNavigationBarStyle:LPVNavBarDefault];
    }
}

/* Prefer hiding the status bar if we're full screen. */
- (BOOL)prefersStatusBarHidden {
    return self.playerView.fullscreen;
}

#pragma mark - Interface

- (void)showQueue:(id)sender {
    [self performSegueWithIdentifier:@"showQueue" sender:self];
}

#pragma mark - Managing the detail item

- (void)setMediaToPlay:(id)newMediaToPlay {
    if (_mediaToPlay != newMediaToPlay) {
        _mediaToPlay = newMediaToPlay;
        if ([newMediaToPlay isKindOfClass:[ExMedia class]]) {
            self.playbackEnabled = NO;
            [newMediaToPlay reloadWithCompletion:^(NSError * _Nullable error) {
                if (error) {
                    NSLog(@"Failed to reload media: %@", error);
                    // show alert
                    AlertHelper *helper = [[AlertHelper alloc] init];
                    helper.cancelButtonTitle = NSLocalizedString(@"OK", nil);
                    helper.title = NSLocalizedString(@"Failed to load media file", nil);
                    helper.message = NSLocalizedString(@"Please try again later", nil);
                    [helper showOnController:self sourceView:_playerView];
                } else {
                    [self.playerView playbackEnabled:YES];
                    self.playbackEnabled = YES;
                }
            }];
        } else {
            self.playbackEnabled = YES;
        }
        [self syncTextToMedia];
    }
}

- (void)syncTextToMedia {
    self.mediaTitle.text = self.mediaToPlay.title;
    self.mediaSubtitle.text = self.mediaToPlay.subtitle;
    self.mediaDescription.text = self.mediaToPlay.descrip;
}

#pragma mark - Handling the queue button's display state

- (void)updateQueueButton {
    CastDeviceController *deviceController = [CastDeviceController sharedInstance];
    if (deviceController.deviceManager.applicationConnectionState == GCKConnectionStateConnected
        && [deviceController.mediaControlChannel.mediaStatus queueItemCount] > 0) {
        if (![self.navigationItem.rightBarButtonItems containsObject:_showQueueButton]) {
            NSMutableArray *rightBarButtons = [self.navigationItem.rightBarButtonItems mutableCopy];
            [rightBarButtons addObject:_showQueueButton];
            self.navigationItem.rightBarButtonItems = rightBarButtons;
        }
    } else {
        NSMutableArray *rightBarButtons = [self.navigationItem.rightBarButtonItems mutableCopy];
        [rightBarButtons removeObject:_showQueueButton];
        self.navigationItem.rightBarButtonItems = rightBarButtons;
    }
}

#pragma mark - LocalPlayerController

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
    } else if (style == LPVNavBarTransparent) {
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

/* Request the navigation bar to be hidden or shown. */
- (void)hideNavigationBar:(BOOL)hide {
    [self.navigationController.navigationBar setHidden:hide];
}

/* Play has been pressed in the LocalPlayerView. */
- (BOOL)continueAfterPlayButtonClicked {
    CastDeviceController *controller = [CastDeviceController sharedInstance];
    if (controller.deviceManager.applicationConnectionState != GCKConnectionStateConnected) {
        NSTimeInterval pos =
        [controller streamPositionForPreviouslyCastMedia:_mediaToPlay.URL.absoluteString];
        if (pos > 0) {
            _playerView.playbackTime = pos;
            // We are playing locally, so don't try and reconnect.
            [controller clearPreviousSession];
        }
        return YES;
    }
    
    AlertHelper *helper = [[AlertHelper alloc] init];
    helper.cancelButtonTitle = NSLocalizedString(@"Cancel", nil);
    
    GCKMediaInformation *media = [GCKMediaInformation mediaInformationFromLocalMedia:_mediaToPlay];
    
    // Play Now blindly loads the media, clobbering the current queue.
    [helper addAction:NSLocalizedString(@"Play Now", nil) handler:^{
        [controller mediaPlayNow:media];
    }];
    
    // Play Next is available if something is currently being played.
    if (controller.mediaInformation) {
        [helper addAction:NSLocalizedString(@"Play Next", nil) handler:^{
            [controller mediaPlayNext:media];
        }];
        
        // Add To Queue adds to the end of the queue.
        [helper addAction:NSLocalizedString(@"Add To Queue", nil) handler:^{
            [controller mediaAddToQueue:media];
        }];
    }
    
    [helper showOnController:self sourceView:_playerView];
    return NO;
}

#pragma mark - ChromecastControllerDelegate

/**
 * Called when connection to the device was established.
 *
 * @param device The device to which the connection was established.
 */
- (void)didConnectToDevice:(GCKDevice *)device {
    [self updateQueueButton];
    
    if (_playerView.playingLocally) {
        [_playerView pause];
        
        // When we connect to a new device and are playing locally, always clobber the currently
        // playing video (as per Android).
        CastDeviceController *controller = [CastDeviceController sharedInstance];
        GCKMediaInformation *media = [GCKMediaInformation mediaInformationFromLocalMedia:_mediaToPlay];

        [controller.mediaControlChannel loadMedia:media
                                         autoplay:YES
                                     playPosition:_playerView.playbackTime];
    }
    
    [_playerView showSplashScreen];
}

- (void)didDisconnect {
    [self updateQueueButton];
}

/**
 * Called to display the modal device view controller from the cast icon.
 */
- (BOOL)shouldDisplayModalDeviceController {
    [self.playerView pause];
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) {
        // If we are likely to have a fullscreen display, don't reset our edges
        // to avoid issues on iOS 7.
        _resetEdgesOnDisappear = NO;
    }
    return YES;
}

/**
 *  Trigger the icon to appear if a device is discovered. 
 */
- (void)didDiscoverDeviceOnNetwork {
    if (![CastInstructionsViewController hasSeenInstructions]) {
        [self hideNavigationBar:NO]; // Display the nav bar for the instructions.
        _resetEdgesOnDisappear = NO;
    }
}

@end