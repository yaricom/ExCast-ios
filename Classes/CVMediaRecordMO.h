//
//  CVMediaRecordMO.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 2/29/16.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

FOUNDATION_EXPORT NSString*_Nonnull const kMediaRecordEntityName;

@class CVGenreMO;
@class CVMediaTrack;

NS_ASSUME_NONNULL_BEGIN

@interface CVMediaRecordMO : NSManagedObject

/**
 Checkens whether this record was already played at least once
 */
- (BOOL) hasBeenSeen;
/**
 Returns page url as URL object
 */
- (NSURL *) pageURL;

/**
 Returns thumbnail URL as URL object
 */
- (NSURL *) thumbnailURL;

/**
 Returns media track at specified index or nil
 */
- (CVMediaTrack *) trackAtIndex: (NSInteger) index;

@end

NS_ASSUME_NONNULL_END

#import "CVMediaRecordMO+CoreDataProperties.h"
