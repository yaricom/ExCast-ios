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
#import "ExMedia.h"
#import "MediaTableViewController.h"
#import "MediaTracksTableViewController.h"
#import "NotificationConstants.h"
#import "SimpleImageFetcher.h"
#import "AlertHelper.h"
#import "CVMediaRecordMO.h"

#import <GoogleCast/GCKDeviceManager.h>
#import <GoogleCast/GCKMediaControlChannel.h>

#define kDefaultRowHeight 40
#define kMediaRowHeight 80

static NSString *const kShowMediaTracksSegue = @"showMediaTracks";

@interface MediaTableViewController () <CastDeviceControllerDelegate>

/** The queue button. */
@property(nonatomic, strong) UIBarButtonItem *showQueueButton;

/** The media records */
@property (nonatomic, strong) NSMutableArray<CVMediaRecordMO*>* records;

@end

@implementation MediaTableViewController {
    UIBarButtonItem *editItem;
    UIBarButtonItem *doneItem;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // create toolbar
    editItem = [[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editTableItems:)];
    doneItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneEditTableItems:)];
    [self initToolbarInEditMode:YES];
    
    // Show stylized application title as a left-aligned image.
    UIView *titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"logo_castvideos.png"]];
    self.navigationItem.titleView = [[UIView alloc] init];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:titleView];
    
    [self reloadMediaList];
    
    // Create the queue button.
    self.showQueueButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"playlist_white.png"]
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:@selector(showQueue:)];
    // assign action to refresh control
    [self.refreshControl addTarget:self
                            action:@selector(reloadMediaList)
                  forControlEvents:UIControlEventValueChanged];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // show toobar
    self.navigationController.toolbarHidden = NO;
    
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
    if ([segue.identifier isEqualToString: kShowMediaTracksSegue]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        CVMediaRecordMO *media = [self.records objectAtIndex:indexPath.row];
        // Pass the currently selected media to the next controller if it needs it.
        MediaTracksTableViewController *vc = (MediaTracksTableViewController*)[segue destinationViewController];
        vc.mediaToPlay = media;
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < [self.records count]) {
        return kMediaRowHeight;
    } else {
        return kDefaultRowHeight;
    }
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < [self.records count]) {
        return kMediaRowHeight;
    } else {
        return kDefaultRowHeight;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.records count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    CVMediaRecordMO *media = [self.records objectAtIndex:indexPath.row];
    
    cell.textLabel.numberOfLines = 2;
    cell.textLabel.text = media.title;
    cell.detailTextLabel.text = media.pageUrl;
    
    // Asynchronously load the table view image
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        UIImage *image = [UIImage imageWithData:[SimpleImageFetcher getDataFromImageURL: [media thumbnailURL]]];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            UIImageView *mediaThumb = cell.imageView;
            [mediaThumb setImage:image];
            [cell setNeedsLayout];
        });
    });
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Display the media details view.
    [self performSegueWithIdentifier:kShowMediaTracksSegue sender:self];
}

// Asks the data source to commit the insertion or deletion of a specified row in the receiver.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // remove from data source and local cache
        CVMediaRecordMO *item = [self.records objectAtIndex:indexPath.row];
        [[[[AppDelegate sharedInstance] dataController] deleteMediaRecordAsync:item]
        continueWithBlock:^id _Nullable(BFTask * _Nonnull task) {
            //
            if (!task.faulted) {
                [self.records removeObject:item];
                [SimpleImageFetcher removeCacheHitForURL: [item thumbnailURL]];
                
                // notify table
                [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            } else {
                AlertHelper *alert = [[AlertHelper alloc] init];
                alert.title = NSLocalizedString(@"Failed to delete", nil);
                alert.message = NSLocalizedString(@"Failed to delete selected media record! Please rfresh list and try again.", nil);
                alert.cancelButtonTitle = NSLocalizedString(@"OK", nil);
                
                [alert showOnController:self sourceView:self.tableView];
                NSLog(@"Failed to delete media record, reason: %@", task.error);
            }
            return nil;
        }];
    }
}

#pragma mark - manage table content
- (void) reloadMediaList {
    // show refresh control if appropriate
    if (!self.refreshControl.refreshing) {
        [self.refreshControl beginRefreshing];
    }
    
    // load media list
    [[[[AppDelegate sharedInstance] dataController] listMediaRecordsAsync]
    continueWithBlock:^id _Nullable(BFTask * _Nonnull task) {
        // store and refresh table view
        if (!task.faulted) {
            self.records = [NSMutableArray arrayWithArray: task.result];
            
        } else {
            AlertHelper *alert = [[AlertHelper alloc] init];
            alert.title = NSLocalizedString(@"Failed to load media", nil);
            alert.message = NSLocalizedString(@"Failed to load list of media records!", nil);
            alert.cancelButtonTitle = NSLocalizedString(@"OK", nil);
            [alert showOnController:self sourceView:self.tableView];
            
            NSLog(@"Failed to load media records, reason: %@", task.error);
        }
        
        [self.tableView reloadData];
        // refresh toolbar
        [self initToolbarInEditMode:YES];
        
        // close refresh control
        if (self.refreshControl.refreshing) {
            [self.refreshControl endRefreshing];
        }
        return nil;
    }];
}

- (void) editTableItems:(id)sender {
    [self.tableView setEditing:YES animated:YES];
    [self initToolbarInEditMode:NO];
}

- (void) doneEditTableItems:(id)sender {
    [self.tableView setEditing:NO animated:YES];
    [self initToolbarInEditMode:YES];
}

- (void) initToolbarInEditMode:(BOOL) edit {
    if (edit) {
        self.toolbarItems = @[[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil], editItem];
        self.toolbarItems[0].enabled = ([self.records count] > 0);
    } else {
        self.toolbarItems = @[[[UIBarButtonItem alloc]initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil], doneItem];
    }
}
@end