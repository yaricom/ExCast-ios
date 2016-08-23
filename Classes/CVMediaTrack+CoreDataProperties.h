//
//  CVMediaTrack+CoreDataProperties.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 6/23/16.
//  Copyright © 2016 Google inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "CVMediaTrack.h"

NS_ASSUME_NONNULL_BEGIN

@interface CVMediaTrack (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSString *address;
@property (nullable, nonatomic, retain) NSNumber *playTime;
@property (nullable, nonatomic, retain) CVMediaRecordMO *record;

@end

NS_ASSUME_NONNULL_END
