//
//  GenreSelectorTableViewController.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 3/1/16.
//

#import <UIKit/UIKit.h>

static NSString * const kSelectedIndexKey;

/*!
 The table view controller to select genre
 */
@interface GenreSelectorTableViewController : UITableViewController

// the list of genres
@property (strong, nonatomic) NSArray<NSString*> *genres;
// the default selected index
@property (assign, nonatomic) NSUInteger selectedIndex;
// the name of notification to use
@property (strong, nonatomic) NSString *selectNotification;

@end
