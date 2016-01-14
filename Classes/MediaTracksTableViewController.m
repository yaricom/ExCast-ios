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

@interface MediaTracksTableViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *posterImage;
@property (weak, nonatomic) IBOutlet UILabel *mediaTitleLbl;

@end

@implementation MediaTracksTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.mediaTitleLbl.text = self.mediaToPlay.title;
    // load poster image
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        UIImage *image = [UIImage
                          imageWithData:[SimpleImageFetcher getDataFromImageURL:self.mediaToPlay.thumbnailURL]];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.posterImage.image = image;
            [self.posterImage setNeedsLayout];
        });
    });
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
    ExMediaTrack *track = [self.mediaToPlay.tracks objectAtIndex:indexPath.row];
    cell.textLabel.text = track.name;
    cell.detailTextLabel.text = [track.url absoluteString];
    
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
        ExMediaTrack *track = self.mediaToPlay.tracks[indexPath.row];
        
        // create new media object
        ExMedia *media = [[ExMedia alloc] init];
        media.URL = track.url;
        media.title = self.mediaToPlay.title;
        media.subtitle = track.name;
        media.pageUrl = self.mediaToPlay.pageUrl;
        media.thumbnailURL = self.mediaToPlay.thumbnailURL;
        media.posterURL = self.mediaToPlay.posterURL;
        
        // Pass the currently selected media to the next controller if it needs it.
        [[segue destinationViewController] setMediaToPlay:media];
    }
}


@end
