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
#import "CastDeviceController.h"
#import "LocalPlayerViewController.h"
#import "Media+Ex.h"
#import "PersistentMediaListModel.h"
#import "MediaTableViewController.h"
#import "NotificationConstants.h"
#import "SimpleImageFetcher.h"
#import "AlertHelper.h"

#import <GoogleCast/GCKDeviceManager.h>
#import <GoogleCast/GCKMediaControlChannel.h>

#define kCellImageSize CGSizeMake(102, 58)

@interface MediaTableViewController () <CastDeviceControllerDelegate>

/** The media to be displayed. */
@property(nonatomic, strong) PersistentMediaListModel *mediaList;

/** The queue button. */
@property(nonatomic, strong) UIBarButtonItem *showQueueButton;
@property (strong, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet UILabel *loadingText;

@end

@implementation MediaTableViewController

- (void)viewDidLoad {
  [super viewDidLoad];

  // Show stylized application title as a left-aligned image.
  UIView *titleView =
      [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"logo_castvideos.png"]];
  self.navigationItem.titleView = [[UIView alloc] init];
  self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:titleView];

  // Asynchronously load the media json.
  AppDelegate *delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
  delegate.mediaList = [[PersistentMediaListModel alloc] init];
  self.mediaList = delegate.mediaList;
  [self.mediaList loadMedia:^{
    self.title = self.mediaList.mediaTitle;
    [self.tableView reloadData];
  }];

  // Create the queue button.
  _showQueueButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"playlist_white.png"]
                                                      style:UIBarButtonItemStylePlain
                                                     target:self
                                                     action:@selector(showQueue:)];
    
    // Hide table header by default
    self.tableView.tableHeaderView = nil;
    
    // create toolbar
    UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *addItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(onAddURLAction:)];
    self.toolbarItems = @[spaceItem, addItem];
    self.navigationController.toolbarHidden = NO;
}

- (void)viewWillAppear:(BOOL)animated {
  [super viewWillAppear:animated];

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
  [super viewWillDisappear:animated];

  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - CastDeviceControllerDelegate

- (void)didConnectToDevice:(GCKDevice *)device {
  [self updateQueueButton];
}

- (void)didDisconnect {
  [self updateQueueButton];
}

#pragma mark - Interface

- (void)showQueue:(id)sender {
  [self performSegueWithIdentifier:@"showQueue" sender:self];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
  if ([segue.identifier isEqualToString:@"playMedia"]) {
    NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
    Media *media = [self.mediaList mediaAtIndex:(int)indexPath.row];
    // Pass the currently selected media to the next controller if it needs it.
    [[segue destinationViewController] setMediaToPlay:media];
  }
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

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return [self.mediaList numberOfMediaLoaded];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  UITableViewCell *cell =
      [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
  Media *media = [self.mediaList mediaAtIndex:(int)indexPath.row];

  UILabel *mediaTitle = (UILabel *)[cell viewWithTag:1];
  mediaTitle.text = media.title;

  UILabel *mediaOwner = (UILabel *)[cell viewWithTag:2];
  mediaOwner.text = media.subtitle;

  // Asynchronously load the table view image
  dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);

  dispatch_async(queue, ^{
    UIImage *image =
        [UIImage imageWithData:[SimpleImageFetcher getDataFromImageURL:media.thumbnailURL]];
    image = [SimpleImageFetcher scaleImage:image toSize:kCellImageSize];

    dispatch_sync(dispatch_get_main_queue(), ^{
      UIImageView *mediaThumb = (UIImageView *)[cell viewWithTag:3];
      [mediaThumb setImage:image];
      [cell setNeedsLayout];
    });
  });

  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  // Display the media details view.
  [self performSegueWithIdentifier:@"playMedia" sender:self];
}

#pragma mark - populate table
- (void)addMediaFromURL:(NSURL *) url {
    [Media mediaFromExURL:url
           withCompletion:^(Media * _Nullable media, NSError * _Nullable error) {
               dispatch_async(dispatch_get_main_queue(), ^{
                   // execute on main UI thread
                   if (error) {
                       NSLog(@"Failed to load data, reason: %@", error);
                       AlertHelper *alert = [[AlertHelper alloc] init];
                       alert.title = @"Failed to load page info";
                       alert.message = @"Please make sure that correct page address provided";
                       alert.cancelButtonTitle = @"OK";
                   } else {
                       // populate table
                       [self addMediaToTable:media];
                   }
                   // hide progress
                   [self showLoadingEnabled:NO withTitle:nil];
               });
           }];
}

- (void) addMediaToTable:(Media *) media {
    [self.mediaList addMedia:media];
    
    [self.tableView reloadData];
}

#pragma mark - Toolbar actions
- (IBAction)onAddURLAction:(id)sender {
    UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Enter page address"
                                                                   message:@"Enter page address as shown in browser"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField * textField) {
        textField.borderStyle = UITextBorderStyleNone;
        textField.text = @"http://www.ex.ua/96457556";
    }];
    
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        NSString *urlText = [alert.textFields[0] text];
        if ([urlText length] > 0) {
            NSURL *url = [NSURL URLWithString:urlText];
            if (url) {
                [self showLoadingEnabled:YES withTitle:[NSString stringWithFormat:@"loading: %@", urlText]];
                [self addMediaFromURL:url];
            } else {
                AlertHelper *alert = [[AlertHelper alloc] init];
                alert.title = @"Wrong page address";
                alert.message = @"Please make sure that correct page address provided";
                alert.cancelButtonTitle = @"Cancel";
            }
        }
    }];
    
    [alert addAction:defaultAction];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel
                                            handler:^(UIAlertAction * action) {}]];
    [self presentViewController:alert animated:YES completion:nil];

}

- (void) showLoadingEnabled:(BOOL)enabled withTitle:(NSString*)title{
    if (enabled) {
        [self.loadingText setText:title];
        self.tableView.tableHeaderView = self.headerView;
        [self.tableView.tableHeaderView sizeToFit];
    } else {
        self.tableView.tableHeaderView = nil;
    }
}
@end