//
//  CVMediaTrack.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 6/23/16.
//  Copyright © 2016 Google inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

FOUNDATION_EXPORT NSString*_Nonnull const kMediaTrackEntityName;

@class CVMediaRecordMO;

NS_ASSUME_NONNULL_BEGIN

@interface CVMediaTrack : NSManagedObject

/**
 Method to get track address as URL object
 */
- (NSURL *) trackURL;

@end

NS_ASSUME_NONNULL_END

#import "CVMediaTrack+CoreDataProperties.h"
