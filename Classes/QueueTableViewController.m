// Copyright 2015 Google Inc. All Rights Reserved.
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

#import "QueueTableViewController.h"

#import "ChromecastDeviceController.h"
#import "SimpleImageFetcher.h"

#import <GoogleCast/GoogleCast.h>

@interface QueueTableViewController () <ChromecastDeviceControllerDelegate>

@property(strong, nonatomic) GCKMediaControlChannel *mediaControlChannel;

@end

@implementation QueueTableViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  _mediaControlChannel = [ChromecastDeviceController sharedInstance].mediaControlChannel;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

  // Assign ourselves as delegate ONLY in viewWillAppear of a view controller.
  ChromecastDeviceController *controller = [ChromecastDeviceController sharedInstance];
  controller.delegate = self;
  self.navigationItem.rightBarButtonItem = [controller queueItemForController:self];
}

- (void)viewWillDisappear:(BOOL)animated {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super viewWillDisappear:animated];
}

#pragma mark - ChromecastDeviceControllerDelegate

- (void)didUpdateQueueForDevice:(GCKDevice *)device {
  [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [_mediaControlChannel.mediaStatus queueItemCount];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
  GCKMediaQueueItem *item = [_mediaControlChannel.mediaStatus queueItemAtIndex:indexPath.row];
  GCKMediaInformation *info = item.mediaInformation;

  UILabel *mediaTitle = (UILabel *)[cell viewWithTag:1];
  UILabel *mediaOwner = (UILabel *)[cell viewWithTag:2];
  UIImageView *mediaPreview = (UIImageView *)[cell viewWithTag:3];

  mediaTitle.text = [info.metadata stringForKey:kGCKMetadataKeyTitle];
  mediaOwner.text = [info.metadata stringForKey:kGCKMetadataKeySubtitle];

  // Update the image, async.
  GCKImage *img = [info.metadata.images objectAtIndex:0];
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    UIImage *image = [UIImage imageWithData:[SimpleImageFetcher getDataFromImageURL:img.URL]];
    dispatch_async(dispatch_get_main_queue(), ^{
      mediaPreview.image = image;
    });
  });


  return cell;
}

// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
  // TODO: support moving
  NSLog(@"Moving row %@ => %@", fromIndexPath, toIndexPath);
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
  // All rows inside the queue may be reordered.
  return YES;
}

@end
