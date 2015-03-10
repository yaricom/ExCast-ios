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

#import <GoogleCast/GoogleCast.h>
#import <Foundation/Foundation.h>

/**
 *  Additional metadata key for the poster image URL.
 */
extern NSString * const kCastComponentPosterURL;

/**
 * The delegate to ChromecastDeviceController. Allows responsding to device and
 * media states and reflecting that in the UI.
 */
@protocol ChromecastControllerDelegate<NSObject>

@optional

/**
 * Called when chromecast devices are discoverd on the network.
 */
- (void)didDiscoverDeviceOnNetwork;

/**
 * Called when connection to the device was established.
 *
 * @param device The device to which the connection was established.
 */
- (void)didConnectToDevice:(GCKDevice*)device;

/**
 * Called when connection to the device was closed.
 */
- (void)didDisconnect;

/**
 * Called when the playback state of media on the device changes.
 */
- (void)didReceiveMediaStateChange;

/**
 * Called to display the modal device view controller from the cast icon. Return
 * NO if the automatic device picker should not be shown.
 */
- (BOOL)shouldDisplayModalDeviceController;

@end

/**
 * Controller for managing the Chromecast device. Provides methods to connect to
 * the device, launch an application, load media and control its playback.
 */
@interface ChromecastDeviceController : NSObject<GCKDeviceScannerListener,
                                                 GCKDeviceManagerDelegate,
                                                 GCKMediaControlChannelDelegate>

/**
 *  The Cast application ID from the cast developers console. This should be set
 *  before the ChromecastDeviceController is used.
 */
@property(nonatomic, copy) NSString *applicationID;

/**
 *  The current delegate for this controller. Set this to enable callbacks for
 *  changes in state of the Cast connection and available devices.
 */
@property(nonatomic, assign) id<ChromecastControllerDelegate> delegate;

/**
 *  The device scanner used to detect devices on the network.
 */
@property(nonatomic, strong) GCKDeviceScanner* deviceScanner;

/**
 *  The device manager used to manage a connection to a Cast device.
 */
@property(nonatomic, strong) GCKDeviceManager* deviceManager;

/**
 *  The media player state of the media on the device.
 */
@property(nonatomic, readonly) GCKMediaPlayerState playerState;

/**
 *  The media information of the loaded media on the device.
 */
@property(nonatomic, readonly) GCKMediaInformation* mediaInformation;

/**
 *  The friendly name of the currently connected device, if any.
 */
@property(readonly, getter=getDeviceName) NSString* deviceName;

/**
 *  The duration of the currently casting media.
 */
@property(nonatomic, readonly) NSTimeInterval streamDuration;

/**
 *  The current playback position of the currently casting media.
 */
@property(nonatomic, readonly) NSTimeInterval streamPosition;

/**
 *  The volume of the currently connected device.
 */
@property(nonatomic) float deviceVolume;

/**
 *  For closed captions and alternate audio tracks, maps which of the available
 *  tracks are currently action. Key is NSNumber for the track identifier and 
 *  value is NSNumber boolean for enabled (1) or disabled (0).
 */
@property(nonatomic, strong) NSMutableDictionary *selectedTrackByIdentifier;

/**
 *  The text track style to use for closed captions. Defaults to system defined style.
 */
@property(nonatomic) GCKMediaTextTrackStyle *textTrackStyle;

/**
 *  The storyboard contianing the Cast component views used by the controllers in 
 *  the CastComponents group.
 */
@property(nonatomic, readonly) UIStoryboard *storyboard;

/**
 *  Main access point for the class. Use this to retriev an object you can use.
 *
 *  @return ChromecastDeviceController
 */
+ (instancetype)sharedInstance;

/**
 *  Request an update for the minicontroller toolbar. Passed UIViewController must have a 
 *  toolbar - for example if it is under a UINavigationBar.
 *
 *  @param viewController UIViewController to update the toolbar on.
 */
- (void)updateToolbarForViewController:(UIViewController *)viewController;

/**
 *  Start or stop scanning to discover devices on the network. Scanning starts automatically
 *  as soon as the application ID is configured. Initiall passiveScan will be used - if using 
 *  your own device selector set deviceScanner.passiveScan = NO in order to enable retrieving
 *  application status. The DeviceTableViewController will disable passive scan on load and reenable
 *  it when it disappears.
 *
 *  @param start YES to start scanning, NO to stop.
 */
- (void)performScan:(BOOL)start;

/**
 *  Connect to the given Cast device.
 *
 *  @param device A GCKDevice from the deviceScanner list.
 */
- (void)connectToDevice:(GCKDevice*)device;

/**
 *  Disconnect from the currently connected device, if any.
 */
- (void)disconnectFromDevice;

/**
 *  Load media onto the currently connected device.
 *
 *  @param media     The GCKMediaInformation to play, with the URL as the contentID
 *  @param startTime Time to start from if starting a fresh cast
 *  @param autoPlay  Whether to start playing as soon as the media is loaded.
 *
 *  @return YES if we can load the media.
 */
- (BOOL)loadMedia:(GCKMediaInformation *)media
        startTime:(NSTimeInterval)startTime
         autoPlay:(BOOL)autoPlay;

/**
 *  Manage the given view controller until told otherwise. Take a weak reference to the controller.
 *  Optionally can also manage the CastIconButton and control toolbar.
 *
 *  @param controller The ViewController to manage.
 *  @param icon       Whether to add and manage a Cast Icon to the navigation controller.
 *  @param toolbar    Whether to update a toolbar.
 */
- (void)manageViewController:(UIViewController *)controller icon:(BOOL)icon toolbar:(BOOL)toolbar;

/**
 *  Current connection status.
 *
 *  @return YES if connected to a Cast device.
 */
- (BOOL)isConnected;

/**
 *  Current playing media status.
 *
 *  @return YES if media is playing on the device.
 */
- (BOOL)isPlayingMedia;

/**
 *  Whether media is loaded, but paused.
 *
 *  @return YES if media loaded but paused.
 */
- (BOOL)isPaused;

/**
 *  Pause or unpause current media.
 *
 *  @param shouldPause YES for pause, NO for play.
 */
- (void)pauseCastMedia:(BOOL)shouldPause;

/**
 *  Request an update of media playback stats from the Cast device.
 */
- (void)updateStatsFromDevice;

/**
 *  Sets the position of the playback on the Cast device.
 *
 *  @param newPercent 0.0-1.0
 */
- (void)setPlaybackPercent:(float)newPercent;

/**
 *  Stops the media playing on the Cast device.
 */
- (void)stopCastMedia;

/**
 *  Sync the active tracks on the device from the selectedTrackByType map.
 */
- (void)updateActiveTracks;

/**
 *  Prevent automatically reconnecting to the Cast device if we see it again.
 */
- (void)clearPreviousSession;

/**
 *  Return the last known stream position for the given contentID. This will generally only
 *  be useful for the last Cast media, and allows a local player to resume playback at the
 *  position noted before disconnect. In many cases it will return 0.
 *
 *  @param contentID The string of the identifier of the media to be displayed.
 *
 *  @return the position in the stream of the media, if any.
 */
- (NSTimeInterval)streamPositionForPreviouslyCastMedia:(NSString *)contentID;

/**
 *  Enable basic logging of all GCKLogger messages to the console.
 */
- (void)enableLogging;

/**
 *  Fetch a CastViewController to represent Cast media.
 *
 *  @param media     GCKMediaInformation with the URL as contentID
 *  @param startTime The time to start from if casting fresh content
 *
 *  @return A UIViewController for displaying the currently casting screen.
 */
- (UIViewController *)castViewControllerForMedia:(GCKMediaInformation *)media
                                  withStartingTime:(NSTimeInterval)startTime;

/**
 *  Trigger appearance of the currently casting screen if content is playing. Requires
 *  that a viewcontroller be set via manageViewController:icon:toolbar.
 */
- (void)displayCurrentlyPlayingMedia;

@end