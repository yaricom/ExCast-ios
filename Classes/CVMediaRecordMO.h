//
//  CVMediaRecordMO.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 2/29/16.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

FOUNDATION_EXPORT NSString* const kMediaRecordEntityName;

@class CVGenreMO;

NS_ASSUME_NONNULL_BEGIN

@interface CVMediaRecordMO : NSManagedObject

/**
 Checkens whether this record was already played at least once
 */
- (BOOL) hasBeenSeen;

@end

NS_ASSUME_NONNULL_END

#import "CVMediaRecordMO+CoreDataProperties.h"
