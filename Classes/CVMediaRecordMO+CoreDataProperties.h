//
//  CVMediaRecordMO+CoreDataProperties.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 6/21/16.
//  Copyright © 2016 Google inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "CVMediaRecordMO.h"

NS_ASSUME_NONNULL_BEGIN

@interface CVMediaRecordMO (CoreDataProperties)

@property (nullable, nonatomic, retain) NSDate *dateAdded;
@property (nullable, nonatomic, retain) NSString *details;
@property (nullable, nonatomic, retain) NSString *pageUrl;
@property (nullable, nonatomic, retain) NSNumber *startTime;
@property (nullable, nonatomic, retain) NSString *title;
@property (nullable, nonatomic, retain) NSNumber *valid;
@property (nullable, nonatomic, retain) NSNumber *neverPlayed;
@property (nullable, nonatomic, retain) NSSet<CVGenreMO *> *genres;

@end

@interface CVMediaRecordMO (CoreDataGeneratedAccessors)

- (void)addGenresObject:(CVGenreMO *)value;
- (void)removeGenresObject:(CVGenreMO *)value;
- (void)addGenres:(NSSet<CVGenreMO *> *)values;
- (void)removeGenres:(NSSet<CVGenreMO *> *)values;

@end

NS_ASSUME_NONNULL_END
