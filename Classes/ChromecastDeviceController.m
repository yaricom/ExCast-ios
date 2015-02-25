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

#import "CastIconButton.h"
#import "CastInstructionsViewController.h"
#import "ChromecastDeviceController.h"
#import "SimpleImageFetcher.h"
#import "TracksTableViewController.h"

static NSString *const kReceiverAppID = @"4F8B3483";  //Replace with your app id

@interface ChromecastDeviceController () <GCKLoggerDelegate> {
  dispatch_queue_t _queue;
}

@property GCKMediaControlChannel *mediaControlChannel;
@property GCKApplicationMetadata *applicationMetadata;
@property GCKDevice *selectedDevice;

@property bool deviceMuted;
@property bool isReconnecting;
@property(nonatomic) NSArray *idleStateToolbarButtons;
@property(nonatomic) NSArray *playStateToolbarButtons;
@property(nonatomic) NSArray *pauseStateToolbarButtons;
@property(nonatomic) UIImageView *toolbarThumbnailImage;
@property(nonatomic) NSURL *toolbarThumbnailURL;
@property(nonatomic) UILabel *toolbarTitleLabel;
@property(nonatomic) UILabel *toolbarSubTitleLabel;
@property(nonatomic) GCKMediaTextTrackStyle *textTrackStyle;
@property(nonatomic) CastIconBarButtonItem *castIconButton;

// TODO(ianbarber): We could have circular references here. Perhaps we should have an
// optional method in the delegate that returns the view controller under control,
// or we require that in the protocol some how.
@property(nonatomic, weak) UIViewController *viewController;
@property(nonatomic) BOOL manageToolbar;

@end

@implementation ChromecastDeviceController

+ (instancetype)sharedInstance {
  static dispatch_once_t p = 0;
  __strong static id _sharedDeviceController = nil;

  dispatch_once(&p, ^{
    _sharedDeviceController = [[self alloc] init];
    // Always start a scan on creation.
    [_sharedDeviceController performScan:YES];
  });

  return _sharedDeviceController;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.isReconnecting = NO;

    // Initialize device scanner
    self.deviceScanner = [[GCKDeviceScanner alloc] init];

    // Create filter criteria to only show devices that can run your app
    GCKFilterCriteria *filterCriteria = [[GCKFilterCriteria alloc] init];
    filterCriteria = [GCKFilterCriteria criteriaForAvailableApplicationWithID:kReceiverAppID];

    // Add the criteria to the scanner to only show devices that can run your app.
    // This allows you to publish your app to the Apple App store before before publishing in Cast console.
    // Once the app is published in Cast console the cast icon will begin showing up on ios devices.
    // If an app is not published in the Cast console the cast icon will only appear for whitelisted dongles
    self.deviceScanner.filterCriteria = filterCriteria;

    // Initialize UI controls for navigation bar and tool bar.
    [self initControls];

    // Queue used for loading thumbnails.
    _queue = dispatch_queue_create("com.google.sample.Chromecast", NULL);

  }
  return self;
}

- (BOOL)isConnected {
  return self.deviceManager.applicationConnectionState == GCKConnectionStateConnected;
}

- (BOOL)isPlayingMedia {
  return  self.deviceManager.connectionState == GCKConnectionStateConnected &&
          self.mediaControlChannel && self.mediaControlChannel.mediaStatus &&
          ( self.playerState == GCKMediaPlayerStatePlaying ||
            self.playerState == GCKMediaPlayerStatePaused ||
            self.playerState == GCKMediaPlayerStateBuffering);
}

- (BOOL)isPaused {
  return self.deviceManager.isConnected && self.mediaControlChannel &&
  self.mediaControlChannel.mediaStatus && self.playerState == GCKMediaPlayerStatePaused;
}

- (void)performScan:(BOOL)start {
  if (start) {
    NSLog(@"Start Scan");
    [self.deviceScanner addListener:self];
    [self.deviceScanner startScan];
  } else {
    NSLog(@"Stop Scan");
    [self.deviceScanner stopScan];
    [self.deviceScanner removeListener:self];
  }
}

- (void)connectToDevice:(GCKDevice *)device {
  NSLog(@"Device address: %@:%d", device.ipAddress, (unsigned int) device.servicePort);
  self.selectedDevice = device;

  NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
  NSString *appIdentifier = [info objectForKey:@"CFBundleIdentifier"];
  self.deviceManager =
      [[GCKDeviceManager alloc] initWithDevice:self.selectedDevice clientPackageName:appIdentifier];
  self.deviceManager.delegate = self;
  [self.deviceManager connect];

  // Start animating the cast connect images.
  self.castIconButton.status = CIBCastConnecting;
}

- (void)disconnectFromDevice {
  NSLog(@"Disconnecting device:%@", self.selectedDevice.friendlyName);
  // We're not going to stop the applicaton in case we're not the last client.
  [self.deviceManager leaveApplication];
  // If you want to force application to stop, uncomment below.
  //[self.deviceManager stopApplication];
  [self.deviceManager disconnect];
}

- (void)updateToolbarForViewController:(UIViewController *)viewController {
  [self updateToolbarStateIn:viewController];
}

- (void)updateStatsFromDevice {
  if (self.isConnected && self.mediaControlChannel && self.mediaControlChannel.mediaStatus) {
    _streamPosition = [self.mediaControlChannel approximateStreamPosition];
    _streamDuration = self.mediaControlChannel.mediaStatus.mediaInformation.streamDuration;

    _playerState = self.mediaControlChannel.mediaStatus.playerState;
    _mediaInformation = self.mediaControlChannel.mediaStatus.mediaInformation;
    if (!self.selectedTrackByIdentifier) {
      [self zeroSelectedTracks];
    }
  }
}

- (void)setDeviceVolume:(float)deviceVolume {
  [self.deviceManager setVolume:deviceVolume];
}

- (void)changeVolumeIncrease:(BOOL)goingUp {
  float idealVolume = self.deviceVolume + (goingUp ? 0.1 : -0.1);
  idealVolume = MIN(1.0, MAX(0.0, idealVolume));

  [self.deviceManager setVolume:idealVolume];
}

- (void)setPlaybackPercent:(float)newPercent {
  newPercent = MAX(MIN(1.0, newPercent), 0.0);

  NSTimeInterval newTime = newPercent * _streamDuration;
  if (_streamDuration > 0 && self.isConnected) {
    [self.mediaControlChannel seekToTimeInterval:newTime];
  }
}

- (void)pauseCastMedia:(BOOL)shouldPause {
  if (self.isConnected && self.mediaControlChannel && self.mediaControlChannel.mediaStatus) {
    if (shouldPause) {
      [self.mediaControlChannel pause];
    } else {
      [self.mediaControlChannel play];
    }
  }
}

- (void)stopCastMedia {
  if (self.isConnected && self.mediaControlChannel && self.mediaControlChannel.mediaStatus) {
    NSLog(@"Telling cast media control channel to stop");
    [self.mediaControlChannel stop];
  }
}

- (void)manageViewController:(UIViewController *)controller icon:(BOOL)icon toolbar:(BOOL)toolbar {
  self.viewController = controller;
  self.manageToolbar = toolbar;
  if (icon) {
    controller.navigationItem.rightBarButtonItem = _castIconButton;
  }
}

- (void)enableLogging {
  [[GCKLogger sharedInstance] setDelegate:self];
}

#pragma mark - GCKDeviceManagerDelegate

- (void)deviceManagerDidConnect:(GCKDeviceManager *)deviceManager {

  if(!self.isReconnecting) {
    [self.deviceManager launchApplication:kReceiverAppID];
  } else {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString* lastSessionID = [defaults valueForKey:@"lastSessionID"];
    [self.deviceManager joinApplication:kReceiverAppID sessionID:lastSessionID];
  }
  [self updateCastIconButtonStates];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
    didConnectToCastApplication:(GCKApplicationMetadata *)applicationMetadata
                      sessionID:(NSString *)sessionID
            launchedApplication:(BOOL)launchedApplication {

  self.isReconnecting = NO;
  self.mediaControlChannel = [[GCKMediaControlChannel alloc] init];
  self.mediaControlChannel.delegate = self;
  [self.deviceManager addChannel:self.mediaControlChannel];
  [self.mediaControlChannel requestStatus];

  self.applicationMetadata = applicationMetadata;
  [self updateCastIconButtonStates];

  if ([self.delegate respondsToSelector:@selector(didConnectToDevice:)]) {
    [self.delegate didConnectToDevice:self.selectedDevice];
  }

  if (self.viewController && self.manageToolbar) {
    [self updateToolbarForViewController:self.viewController];
  }

  // Store sessionID in case of restart
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:sessionID forKey:@"lastSessionID"];
  [defaults setObject:[self.selectedDevice deviceID] forKey:@"lastDeviceID"];
  [defaults synchronize];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
  didFailToConnectToApplicationWithError:(NSError *)error {
  if(self.isReconnecting && [error code] == GCKErrorCodeApplicationNotRunning) {
    // Expected error when unable to reconnect to previous session after another
    // application has been running
    self.isReconnecting = false;
  } else {
    [self showError:error.description];
  }

  [self updateCastIconButtonStates];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
    didFailToConnectWithError:(GCKError *)error {
  [self showError:error.description];

  [self deviceDisconnectedForgetDevice:YES];
  [self updateCastIconButtonStates];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager didDisconnectWithError:(GCKError *)error {
  NSLog(@"Received notification that device disconnected");

  // Network errors are displayed in the suspend code.
  if (error && error.code != GCKErrorCodeNetworkError) {
    [self showError:error.description];
  }

  // Forget the device except when the error is a connectivity related, such a WiFi problem.
  [self deviceDisconnectedForgetDevice:![self isRecoverableError:error]];
  [self updateCastIconButtonStates];

}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
    didDisconnectFromApplicationWithError:(NSError *)error {
  NSLog(@"Received notification that app disconnected");

  if (error) {
    NSLog(@"Application disconnected with error: %@", error);
  }

  // Forget the device except when the error is a connectivity related, such a WiFi problem.
  [self deviceDisconnectedForgetDevice:![self isRecoverableError:error]];
  [self updateCastIconButtonStates];
}

- (BOOL)isRecoverableError:(NSError *)error {
  if (!error) {
    return NO;
  }

  return (error.code == GCKErrorCodeNetworkError ||
          error.code == GCKErrorCodeTimeout ||
          error.code == GCKErrorCodeAppDidEnterBackground);
}

- (void)deviceDisconnectedForgetDevice:(BOOL)clear {
  self.mediaControlChannel = nil;
  _playerState = 0;
  _mediaInformation = nil;
  self.selectedDevice = nil;

  if ([self.delegate respondsToSelector:@selector(didDisconnect)]) {
    [self.delegate didDisconnect];
  }

  // TODO(ianbarber): Maybe move these lines out to a separate function.
  if (self.viewController && self.manageToolbar) {
    [self updateToolbarForViewController:self.viewController];
  }

  if (clear) {
    [self clearPreviousSession];
  }
}

- (void)clearPreviousSession {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults removeObjectForKey:@"lastDeviceID"];
  [defaults synchronize];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
    didReceiveApplicationMetadata:(GCKApplicationMetadata *)applicationMetadata {
  self.applicationMetadata = applicationMetadata;
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
    volumeDidChangeToLevel:(float)volumeLevel
                   isMuted:(BOOL)isMuted {
  _deviceVolume = volumeLevel;
  self.deviceMuted = isMuted;

  // Fire off a notification, so no matter what controller we are in, we can show the volume
  // slider
  [[NSNotificationCenter defaultCenter] postNotificationName:@"Volume changed" object:self];
}

- (void)deviceManager:(GCKDeviceManager *)deviceManager
    didSuspendConnectionWithReason:(GCKConnectionSuspendReason)reason {
  if (reason == GCKConnectionSuspendReasonAppBackgrounded) {
    NSLog(@"Connection Suspended: App Backgrounded");
  } else {
    [self showError:@"Connection Suspended: Network"];
    [self deviceDisconnectedForgetDevice:NO];
    [self updateCastIconButtonStates];
  }
}

- (void)deviceManagerDidResumeConnection:(GCKDeviceManager *)deviceManager
                     rejoinedApplication:(BOOL)rejoinedApplication {
  NSLog(@"Connection Resumed. App Rejoined: %@", rejoinedApplication ? @"YES" : @"NO");
  [self updateCastIconButtonStates];
}

#pragma mark - GCKDeviceScannerListener
- (void)deviceDidComeOnline:(GCKDevice *)device {
  NSLog(@"device found - %@", device.friendlyName);

  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSString* lastDeviceID = [defaults objectForKey:@"lastDeviceID"];
  if(lastDeviceID != nil && [[device deviceID] isEqualToString:lastDeviceID]){
    self.isReconnecting = true;
    [self connectToDevice:device];
  }

  if ([self.delegate respondsToSelector:@selector(didDiscoverDeviceOnNetwork)]) {
    [self.delegate didDiscoverDeviceOnNetwork];
  }

  // Always update after notifying the delegate.
  [self updateCastIconButtonStates];
}

- (void)deviceDidGoOffline:(GCKDevice *)device {
  NSLog(@"device went offline - %@", device.friendlyName);
  [self updateCastIconButtonStates];
}

#pragma mark - GCKMediaControlChannelDelegate methods

- (void)mediaControlChannel:(GCKMediaControlChannel *)mediaControlChannel
    didCompleteLoadWithSessionID:(NSInteger)sessionID {
  _mediaControlChannel = mediaControlChannel;
}

- (void)mediaControlChannelDidUpdateStatus:(GCKMediaControlChannel *)mediaControlChannel {
  [self updateStatsFromDevice];
  NSLog(@"Media control channel status changed");
  _mediaControlChannel = mediaControlChannel;
  [self updateTrackSelectionFromActiveTracks:_mediaControlChannel.mediaStatus.activeTrackIDs];
  if ([self.delegate respondsToSelector:@selector(didReceiveMediaStateChange)]) {
    [self.delegate didReceiveMediaStateChange];
  }
  if (self.viewController && self.manageToolbar) {
    [self updateToolbarForViewController:self.viewController];
  }
}

- (void)mediaControlChannelDidUpdateMetadata:(GCKMediaControlChannel *)mediaControlChannel {
  NSLog(@"Media control channel metadata changed");
  _mediaControlChannel = mediaControlChannel;
  [self updateStatsFromDevice];

  if ([self.delegate respondsToSelector:@selector(didReceiveMediaStateChange)]) {
    [self.delegate didReceiveMediaStateChange];
  }
}

- (BOOL)loadMedia:(NSURL *)url
     thumbnailURL:(NSURL *)thumbnailURL
            title:(NSString *)title
         subtitle:(NSString *)subtitle
         mimeType:(NSString *)mimeType
           tracks:(NSArray *)tracks
        startTime:(NSTimeInterval)startTime
         autoPlay:(BOOL)autoPlay {
  if (!self.deviceManager || self.deviceManager.connectionState != GCKConnectionStateConnected ) {
    return NO;
  }
  // Reset selected tracks.
  self.selectedTrackByIdentifier = nil;
  GCKMediaMetadata *metadata = [[GCKMediaMetadata alloc] init];
  if (title) {
    [metadata setString:title forKey:kGCKMetadataKeyTitle];
  }

  if (subtitle) {
    [metadata setString:subtitle forKey:kGCKMetadataKeySubtitle];
  }

  if (thumbnailURL) {
    [metadata addImage:[[GCKImage alloc] initWithURL:thumbnailURL width:200 height:100]];
  }

  GCKMediaInformation *mediaInformation =
      [[GCKMediaInformation alloc] initWithContentID:[url absoluteString]
                                          streamType:GCKMediaStreamTypeNone
                                         contentType:mimeType
                                            metadata:metadata
                                      streamDuration:0
                                         mediaTracks:tracks
                                      textTrackStyle:[self textTrackStyle]
                                          customData:nil];

  [self.mediaControlChannel loadMedia:mediaInformation autoplay:autoPlay playPosition:startTime];

  return YES;
}

# pragma mark - GCKMediaTextTrackStyle

- (GCKMediaTextTrackStyle *)textTrackStyle {
  if (!_textTrackStyle) {
    // createDefault will use the system captions style via the MediaAccessibility framework
    // in iOS 7 and above. For apps which support iOS 6 you may want to implement a Settings
    // bundle and customise a GCKMediaTextTrackStyle manually on those systems.
    _textTrackStyle = [GCKMediaTextTrackStyle createDefault];
  }
  return _textTrackStyle;
}

#pragma mark - implementation

- (void)showError:(NSString *)errorDescription {
  NSLog(@"Received error: %@", errorDescription);
  UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Cast Error", nil)
                                                  message:NSLocalizedString(@"An error occurred. Make sure your Chromecast is powered up and connected to the network.", nil)
                                                 delegate:nil
                                        cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                        otherButtonTitles:nil];
  [alert show];
}

- (NSString *)getDeviceName {
  if (self.selectedDevice == nil)
    return @"";
  return self.selectedDevice.friendlyName;
}

- (void)initControls {
  _castIconButton = [CastIconBarButtonItem barButtonItemWithTarget:self
                                                          selector:@selector(chooseDevice:)];

  // Create toolbar buttons for the mini player.
  CGRect frame = CGRectMake(0, 0, 49, 37);
  _toolbarThumbnailImage =
      [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"video_thumb_mini.png"]];
  _toolbarThumbnailImage.frame = frame;
  _toolbarThumbnailImage.contentMode = UIViewContentModeScaleAspectFit;
  UIButton *someButton = [[UIButton alloc] initWithFrame:frame];
  [someButton addSubview:_toolbarThumbnailImage];
  [someButton addTarget:self
                 action:@selector(showMedia)
       forControlEvents:UIControlEventTouchUpInside];
  [someButton setShowsTouchWhenHighlighted:YES];
  UIBarButtonItem *thumbnail = [[UIBarButtonItem alloc] initWithCustomView:someButton];

  UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
  [btn setFrame:CGRectMake(0, 0, 200, 45)];
  _toolbarTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 185, 30)];
  _toolbarTitleLabel.backgroundColor = [UIColor clearColor];
  _toolbarTitleLabel.font = [UIFont systemFontOfSize:17];
  _toolbarTitleLabel.text = @"This is the title";
  _toolbarTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  _toolbarTitleLabel.textColor = [UIColor blackColor];
  [btn addSubview:_toolbarTitleLabel];

  _toolbarSubTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 185, 30)];
  _toolbarSubTitleLabel.backgroundColor = [UIColor clearColor];
  _toolbarSubTitleLabel.font = [UIFont systemFontOfSize:14];
  _toolbarSubTitleLabel.text = @"This is the sub";
  _toolbarSubTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
  _toolbarSubTitleLabel.textColor = [UIColor grayColor];
  [btn addSubview:_toolbarSubTitleLabel];
  [btn addTarget:self action:@selector(showMedia) forControlEvents:UIControlEventTouchUpInside];
  UIBarButtonItem *titleBtn = [[UIBarButtonItem alloc] initWithCustomView:btn];

  UIBarButtonItem *flexibleSpaceLeft =
      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                    target:nil
                                                    action:nil];

  UIBarButtonItem *playButton =
      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                    target:self
                                                    action:@selector(playMedia)];
  playButton.tintColor = [UIColor blackColor];

  UIBarButtonItem *pauseButton =
      [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPause
                                                    target:self
                                                    action:@selector(pauseMedia)];
  pauseButton.tintColor = [UIColor blackColor];

  _idleStateToolbarButtons = [NSArray arrayWithObjects:thumbnail, titleBtn, flexibleSpaceLeft, nil];
  _playStateToolbarButtons =
      [NSArray arrayWithObjects:thumbnail, titleBtn, flexibleSpaceLeft, pauseButton, nil];
  _pauseStateToolbarButtons =
      [NSArray arrayWithObjects:thumbnail, titleBtn, flexibleSpaceLeft, playButton, nil];
}

- (void)chooseDevice:(id)sender {
  if ([self.delegate respondsToSelector:@selector(shouldDisplayModalDeviceController)]) {
    [_delegate shouldDisplayModalDeviceController];
  }
}

- (void)updateToolbarStateIn:(UIViewController *)viewController {
  // Ignore this view controller if it is not visible.
  if (!(viewController.isViewLoaded && viewController.view.window)) {
    return;
  }
  // Get the playing status.
  if (self.isPlayingMedia) {
    viewController.navigationController.toolbarHidden = NO;
  } else {
    viewController.navigationController.toolbarHidden = YES;
    return;
  }

  // Update the play/pause state.
  if (self.playerState == GCKMediaPlayerStateUnknown ||
      self.playerState == GCKMediaPlayerStateIdle) {
    viewController.toolbarItems = self.idleStateToolbarButtons;
  } else {
    BOOL playing = (self.playerState == GCKMediaPlayerStatePlaying ||
                    self.playerState == GCKMediaPlayerStateBuffering);
    if (playing) {
      viewController.toolbarItems = self.playStateToolbarButtons;
    } else {
      viewController.toolbarItems = self.pauseStateToolbarButtons;
    }
  }

  // Update the title.
  self.toolbarTitleLabel.text = [self.mediaInformation.metadata stringForKey:kGCKMetadataKeyTitle];
  self.toolbarSubTitleLabel.text =
      [self.mediaInformation.metadata stringForKey:kGCKMetadataKeySubtitle];

  // Update the image.
  GCKImage *img = [self.mediaInformation.metadata.images objectAtIndex:0];
  if ([img.URL isEqual:self.toolbarThumbnailURL]) {
    return;
  }

  //Loading thumbnail async
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    UIImage *image = [UIImage imageWithData:[SimpleImageFetcher getDataFromImageURL:img.URL]];

    dispatch_async(dispatch_get_main_queue(), ^{
      self.toolbarThumbnailURL = img.URL;
      self.toolbarThumbnailImage.image = image;
    });
  });
}

- (void)playMedia {
  [self pauseCastMedia:NO];
}

- (void)pauseMedia {
  [self pauseCastMedia:YES];
}

- (void)showMedia {
  if ([self.delegate respondsToSelector:@selector(shouldPresentPlaybackController)]) {
    [self.delegate shouldPresentPlaybackController];
  }
}

- (void)updateCastIconButtonStates {
  if (self.deviceScanner.devices.count == 0) {
    _castIconButton.status = CIBCastUnavailable;
  } else if (self.deviceManager.applicationConnectionState == GCKConnectionStateConnecting) {
    _castIconButton.status = CIBCastConnecting;
  } else if (self.deviceManager.applicationConnectionState == GCKConnectionStateConnected) {
    _castIconButton.status = CIBCastConnected;
  } else {
    _castIconButton.status = CIBCastAvailable;
    // Show cast icon. If this is the first time the cast icon is appearing, show an overlay with
    // instructions highlighting the cast icon.
    if (self.viewController) {
      [CastInstructionsViewController showIfFirstTimeOverViewController:self.viewController];
    }
  }
}

# pragma mark - Tracks management

- (void)updateActiveTracks {
  NSMutableArray *tracks = [NSMutableArray arrayWithCapacity:[self.selectedTrackByIdentifier count]];
  NSEnumerator *enumerator = [self.selectedTrackByIdentifier keyEnumerator];
  NSNumber *key;
  while ((key = [enumerator nextObject])) {
    if ([[self.selectedTrackByIdentifier objectForKey:key] boolValue]) {
      [tracks addObject:key];
    }
  }
  [self.mediaControlChannel setActiveTrackIDs:tracks];
}

- (void)updateTrackSelectionFromActiveTracks:(NSArray *)activeTracks {
  if ([_mediaControlChannel.mediaStatus.activeTrackIDs count] == 0) {
    [self zeroSelectedTracks];
  }

  NSEnumerator *enumerator = [self.selectedTrackByIdentifier keyEnumerator];
  NSNumber *key;
  while ((key = [enumerator nextObject])) {
    [self.selectedTrackByIdentifier
        setObject:[NSNumber numberWithBool:[activeTracks containsObject:key]]
           forKey:key];
    }
}

- (void)zeroSelectedTracks {
  // Disable tracks.
  self.selectedTrackByIdentifier =
      [NSMutableDictionary dictionaryWithCapacity:[self.mediaInformation.mediaTracks count]];
  NSNumber *nope = [NSNumber numberWithBool:NO];
  for (GCKMediaTrack *track in self.mediaInformation.mediaTracks) {
    [self.selectedTrackByIdentifier setObject:nope
                                       forKey:[NSNumber numberWithInteger:track.identifier]];
  }
}

#pragma mark - GCKLoggerDelegate implementation

- (void)logFromFunction:(const char *)function message:(NSString *)message {
  // Send SDK’s log messages directly to the console, as an example.
  NSLog(@"%s  %@", function, message);
}

@end
