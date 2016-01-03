//
//  PersistentMediaListModel.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/3/16.
//

#import <Foundation/Foundation.h>

#import "Media+Ex.h"

/**
 * The media list model able to keep list of media objects persistent
 */
@interface PersistentMediaListModel : NSObject

/* Top level title of the list of media: ex: Videos. */
@property(nonatomic, strong) NSString *mediaTitle;

/* The number of media objects in the array. */
@property(nonatomic, readonly) int numberOfMediaLoaded;

/* Loads all medias and calls the supplied callback on completion. */
- (void)loadMedia:(void (^)(void))callbackBlock;

/* Returns the media object at index. */
- (Media *)mediaAtIndex:(int)index;

/* Adds specified media to the list */
- (void) addMedia:(Media *) media;

/* Return the index of the first media object with matching title. */
- (int)indexOfMediaByTitle:(NSString *)title;

@end
