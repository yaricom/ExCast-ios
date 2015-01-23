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
#import "DeviceTableViewController.h"
#import "ChromecastDeviceController.h"
#import "SimpleImageFetcher.h"

@implementation DeviceTableViewController {
  BOOL _isManualVolumeChange;
  UISlider *_volumeSlider;
}

- (ChromecastDeviceController *)castDeviceController {
  AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
  return delegate.chromecastDeviceController;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  // Return the number of sections - section 0 is main list, section 1 is version footer.
  return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  if (section == 1) {
    return 1;
  }
  // Return the number of rows in the section.
  if (self.castDeviceController.isConnected == NO) {
    self.title = @"Connect to";
    return self.castDeviceController.deviceScanner.devices.count;
  } else {
    self.title =
        [NSString stringWithFormat:@"%@", self.castDeviceController.deviceName];
    return 3;
  }
}

// Return a configured version table view cell.
- (UITableViewCell *)tableView:(UITableView *)tableView
  versionCellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdForVersion = @"version";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdForVersion
                                                          forIndexPath:indexPath];
  NSString *ver = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
  [cell.textLabel setText:[NSString stringWithFormat:@"CastVideos-iOS version %@", ver]];
  return cell;
}

// Return a configured device table view cell.
- (UITableViewCell *)tableView:(UITableView *)tableView
  deviceCellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdForDeviceName = @"deviceName";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdForDeviceName
                                                          forIndexPath:indexPath];
  GCKDevice *device = [self.castDeviceController.deviceScanner.devices objectAtIndex:indexPath.row];
  cell.textLabel.text = device.friendlyName;
  cell.detailTextLabel.text = device.statusText ? device.statusText : device.modelName;
  return cell;
}

// Return a configured playing media table view cell.
- (UITableViewCell *)tableView:(UITableView *)tableView
   mediaCellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdForPlayerController = @"playerController";
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdForPlayerController
                                                          forIndexPath:indexPath];
  cell.textLabel.text =
  [self.castDeviceController.mediaInformation.metadata stringForKey:kGCKMetadataKeyTitle];
  cell.detailTextLabel.text = [self.castDeviceController.mediaInformation.metadata
                               stringForKey:kGCKMetadataKeySubtitle];

  // Accessory is the play/pause button.
  BOOL paused = self.castDeviceController.playerState == GCKMediaPlayerStatePaused;
  UIImage *playImage = (paused ? [UIImage imageNamed:@"play_black.png"]
                        : [UIImage imageNamed:@"pause_black.png"]);
  CGRect frame = CGRectMake(0, 0, playImage.size.width, playImage.size.height);
  UIButton *button = [[UIButton alloc] initWithFrame:frame];
  [button setBackgroundImage:playImage forState:UIControlStateNormal];
  [button addTarget:self
             action:@selector(playPausePressed:)
   forControlEvents:UIControlEventTouchUpInside];
  cell.accessoryView = button;

  // Asynchronously load the table view image
  if (self.castDeviceController.mediaInformation.metadata.images.count > 0) {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

    dispatch_async(queue, ^{
      GCKImage *mediaImage =
      [self.castDeviceController.mediaInformation.metadata.images objectAtIndex:0];
      UIImage *image =
      [UIImage imageWithData:[SimpleImageFetcher getDataFromImageURL:mediaImage.URL]];

      CGSize itemSize = CGSizeMake(40, 40);
      UIImage *thumbnailImage = [self scaleImage:image toSize:itemSize];

      dispatch_sync(dispatch_get_main_queue(), ^{
        UIImageView *mediaThumb = cell.imageView;
        [mediaThumb setImage:thumbnailImage];
        [cell setNeedsLayout];
      });
    });
  }
  return cell;
}

// Return a configured volume control table view cell.
- (UITableViewCell *)tableView:(UITableView *)tableView
    volumeCellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdForVolumeControl = @"volumeController";
  static int TagForVolumeSlider = 201;
  UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdForVolumeControl
                                         forIndexPath:indexPath];

  _volumeSlider = (UISlider *)[cell.contentView viewWithTag:TagForVolumeSlider];
  _volumeSlider.minimumValue = 0;
  _volumeSlider.maximumValue = 1.0;
  _volumeSlider.value = [self castDeviceController].deviceVolume;
  _volumeSlider.continuous = NO;
  [_volumeSlider addTarget:self
                    action:@selector(sliderValueChanged:)
          forControlEvents:UIControlEventValueChanged];
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(receivedVolumeChangedNotification:)
                                               name:@"Volume changed"
                                             object:[self castDeviceController]];
  return cell;
}


- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  static NSString *CellIdForReadyStatus = @"readyStatus";
  static NSString *CellIdForDisconnectButton = @"disconnectButton";

  UITableViewCell *cell;

  if (indexPath.section == 1) {
    // Version string.
    cell = [self tableView:tableView versionCellForRowAtIndexPath:indexPath];
  } else if (self.castDeviceController.isConnected == NO) {
    // Device chooser.
    cell = [self tableView:tableView deviceCellForRowAtIndexPath:indexPath];
  } else {
    // Connection manager.
    if (indexPath.row == 0) {
      if (self.castDeviceController.isPlayingMedia == NO) {
        // Display the ready status message.
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdForReadyStatus
                                               forIndexPath:indexPath];
      } else {
        // Display the view describing the playing media.
        cell = [self tableView:tableView mediaCellForRowAtIndexPath:indexPath];
      }
    } else if (indexPath.row == 1) {
      // Display the volume controller.
      cell = [self tableView:tableView volumeCellForRowAtIndexPath:indexPath];
    } else if (indexPath.row == 2) {
      // Display disconnect control as last cell.
      cell = [tableView dequeueReusableCellWithIdentifier:CellIdForDisconnectButton
                                             forIndexPath:indexPath];
    }
  }

  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  if (self.castDeviceController.isConnected == NO) {
    if (indexPath.row < self.castDeviceController.deviceScanner.devices.count) {
      GCKDevice *device =
          [self.castDeviceController.deviceScanner.devices objectAtIndex:indexPath.row];
      NSLog(@"Selecting device:%@", device.friendlyName);
      [self.castDeviceController connectToDevice:device];
    }
  } else if (self.castDeviceController.isPlayingMedia == YES && indexPath.row == 0) {
    if ([self.castDeviceController.delegate
            respondsToSelector:@selector(shouldPresentPlaybackController)]) {
      [self.castDeviceController.delegate shouldPresentPlaybackController];
    }
  }
  // Dismiss the view.
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView
    accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
  NSLog(@"Accesory button tapped");
}

- (IBAction)disconnectDevice:(id)sender {
  [self.castDeviceController disconnectFromDevice];

  // Dismiss the view.
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)dismissView:(id)sender {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)playPausePressed:(id)sender {
  BOOL paused = self.castDeviceController.playerState == GCKMediaPlayerStatePaused;
  [self.castDeviceController pauseCastMedia:!paused];

  // change the icon.
  UIButton *button = sender;
  UIImage *playImage =
      (paused ? [UIImage imageNamed:@"play_black.png"] : [UIImage imageNamed:@"pause_black.png"]);
  [button setBackgroundImage:playImage forState:UIControlStateNormal];
}

#pragma mark - implementation
- (UIImage *)scaleImage:(UIImage *)image toSize:(CGSize)newSize {
  CGSize scaledSize = newSize;
  float scaleFactor = 1.0;
  if (image.size.width > image.size.height) {
    scaleFactor = image.size.width / image.size.height;
    scaledSize.width = newSize.width;
    scaledSize.height = newSize.height / scaleFactor;
  } else {
    scaleFactor = image.size.height / image.size.width;
    scaledSize.height = newSize.height;
    scaledSize.width = newSize.width / scaleFactor;
  }

  UIGraphicsBeginImageContextWithOptions(scaledSize, NO, 0.0);
  CGRect scaledImageRect = CGRectMake(0.0, 0.0, scaledSize.width, scaledSize.height);
  [image drawInRect:scaledImageRect];
  UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return scaledImage;
}

# pragma mark - volume

- (void)receivedVolumeChangedNotification:(NSNotification *) notification {
  if(!_isManualVolumeChange) {
    ChromecastDeviceController *deviceController = (ChromecastDeviceController *) notification.object;
    _volumeSlider.value = deviceController.deviceVolume;
  }
}

- (IBAction)sliderValueChanged:(id)sender {
  UISlider *slider = (UISlider *) sender;
  _isManualVolumeChange = YES;
  NSLog(@"Got new slider value: %.2f", slider.value);
  [self castDeviceController].deviceVolume = slider.value;
  _isManualVolumeChange = NO;
}

@end