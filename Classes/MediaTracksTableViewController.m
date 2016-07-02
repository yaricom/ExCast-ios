//
//  MediaTracksTableViewController.m
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/14/16.
//  Copyright © 2016 Google inc. All rights reserved.
//

#import "MediaTracksTableViewController.h"

#import "SimpleImageFetcher.h"
#import "ExMediaTrack.h"
#import "ExMedia.h"
#import "CastDeviceController.h"
#import "NotificationConstants.h"
#import "AlertHelper.h"
#import "LocalPlayerViewController.h"
#import "AppDelegate.h"
#import "CVMediaTrack.h"

#import <GoogleCast/GCKDeviceManager.h>
#import <GoogleCast/GCKMediaControlChannel.h>

@interface MediaTracksTableViewController () <CastDeviceControllerDelegate>

@property (weak, nonatomic) IBOutlet UIImageView *posterImage;
@property (weak, nonatomic) IBOutlet UILabel *mediaTitleLbl;


/** The queue button. */
@property(nonatomic, strong) UIBarButtonItem *showQueueButton;

@end

@implementation MediaTracksTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.mediaTitleLbl.text = self.mediaToPlay.title;
    // load poster image
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        UIImage *image = [UIImage imageWithData:[SimpleImageFetcher getDataFromImageURL:[NSURL URLWithString:self.mediaToPlay.thumbnailUrl]]];
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.posterImage.image = image;
            [self.posterImage setNeedsLayout];
        });
    });
    
    // Create the queue button.
    self.showQueueButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"playlist_white.png"]
                                                            style:UIBarButtonItemStylePlain
                                                           target:self
                                                           action:@selector(showQueue:)];
    
    [self.refreshControl addTarget: self
                            action: @selector(loadMediaTracks)
                  forControlEvents: UIControlEventValueChanged];
    
    if ([self.mediaToPlay.tracks count] == 0) {
        [self loadMediaTracks];
    }
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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.mediaToPlay.tracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    
    // Configure the cell...
    CVMediaTrack *track = [self.mediaToPlay.tracks objectAtIndex:indexPath.row];
    cell.textLabel.text = track.name;
    cell.detailTextLabel.text = track.address;

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Display the media details view.
    [self performSegueWithIdentifier:@"playMedia" sender:self];
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"playMedia"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        
        // Pass the currently selected media to the next controller if it needs it.
        [[segue destinationViewController] setMediaTrack:indexPath.row fromRecord:self.mediaToPlay];
    }
}

- (void)showQueue:(id)sender {
    [self performSegueWithIdentifier:@"showQueue" sender:self];
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

#pragma mark - CastDeviceControllerDelegate

- (void)didConnectToDevice:(GCKDevice *)device {
    [self updateQueueButton];
}

- (void)didDisconnect {
    [self updateQueueButton];
}

#pragma mark - private 
- (void) onRemoteFetchComplete: (ExMedia *) media {
    for (ExMediaTrack *track in media.tracks) {
        [[[[AppDelegate sharedInstance] dataController] createTrackWithURL:track.url title:track.name forRecord:self.mediaToPlay]
         continueWithBlock:^id _Nullable(BFTask * _Nonnull task) {
             //
             if (task.faulted) {
                 NSLog(@"Failed to store media track, reason: %@", task.error);
             }
             
             return nil;
         }];
    }
}

- (void) loadMediaTracks {
    [self initToolbarWithProgress: YES];
    
    // show refresh control if appropriate
    if (!self.refreshControl.refreshing) {
        [self.refreshControl beginRefreshing];
    }
    
    // remove existing tracks
    [[[[AppDelegate sharedInstance] dataController] deleteMediaTracksForRecordAsync:self.mediaToPlay]
     continueWithBlock:^id _Nullable(BFTask * _Nonnull task) {
         if (!task.faulted) {
             [self.tableView reloadData];
             // load new tracks
             [self loadRemote];
         } else {
             NSLog(@"Failed to delete media tracks, reason: %@", task.error);
         }
         
         return nil;
     }];
}

- (void) loadRemote {
    [ExMedia mediaFromExURL: [self.mediaToPlay pageURL] withCompletion:
     ^(ExMedia * _Nullable media, NSError * _Nullable error) {
         dispatch_async(dispatch_get_main_queue(), ^{
             // execute on main UI thread
             if (error) {
                 NSLog(@"Failed to load data, reason: %@", error);
                 AlertHelper *alert = [[AlertHelper alloc] init];
                 alert.title = NSLocalizedString(@"Failed to load remote media", nil);
                 alert.message = NSLocalizedString(@"Remote media was not found. It may be deleted from server or connection to server lost. Please try again later and check that media still present on server.", nil);
                 alert.cancelButtonTitle = NSLocalizedString(@"OK", nil);
                 [alert showOnController:self sourceView:self.tableView];
                 
                 // mark record as invalid
                 self.mediaToPlay.valid = [NSNumber numberWithBool:NO];
             } else {
                 self.mediaToPlay.valid = [NSNumber numberWithBool:YES];
                 // populate table
                 [self onRemoteFetchComplete: media];
             }
             
             [self.tableView reloadData];
             
             // close refresh control
             if (self.refreshControl.refreshing) {
                 [self.refreshControl endRefreshing];
             }
             
             [self initToolbarWithProgress: NO];
         });
     }];
}

- (void) initToolbarWithProgress: (BOOL)enabled {
    self.navigationController.toolbarHidden = !enabled;
    if (enabled) {
        UIBarButtonItem *spacerItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
        
        UIActivityIndicatorView *progress = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        [progress startAnimating];
        UIBarButtonItem *progressItem = [[UIBarButtonItem alloc] initWithCustomView: progress];
        
        UILabel *prompt = [UILabel new];
        prompt.text = NSLocalizedString(@"Loading tracks from remote...", nil);
        prompt.numberOfLines = 0;
        prompt.font = [UIFont systemFontOfSize:13];
        [prompt sizeToFit];
        prompt.lineBreakMode = NSLineBreakByTruncatingTail;
        UIBarButtonItem *promptItem = [[UIBarButtonItem alloc] initWithCustomView:prompt];
        
        self.toolbarItems = @[promptItem, spacerItem, progressItem];
    }
}


@end
