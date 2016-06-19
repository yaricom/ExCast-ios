//
//  GenreSelectorTableViewController.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 3/1/16.
//

#import <UIKit/UIKit.h>

static NSString * const kSelectedIndexKey;

@protocol GenreSelectorDelegate

- (void)onGenreSelected:(NSUInteger)index forType:(NSString*)type;

@end

/*!
 The table view controller to select genre
 */
@interface GenreSelectorTableViewController : UITableViewController

// the delegate
@property (nonatomic, assign) id<GenreSelectorDelegate> delegate;

// the list of genres
@property (strong, nonatomic) NSArray<NSString*> *genres;
// the default selected index
@property (assign, nonatomic) NSUInteger selectedIndex;
// the name of genre type
@property (strong, nonatomic) NSString *genreType;

@end
