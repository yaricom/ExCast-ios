//
//  CVGenreMO+CoreDataProperties.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 6/23/16.
//  Copyright © 2016 Google inc. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "CVGenreMO.h"

NS_ASSUME_NONNULL_BEGIN

@interface CVGenreMO (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSSet<CVMediaRecordMO *> *records;

@end

@interface CVGenreMO (CoreDataGeneratedAccessors)

- (void)addRecordsObject:(CVMediaRecordMO *)value;
- (void)removeRecordsObject:(CVMediaRecordMO *)value;
- (void)addRecords:(NSSet<CVMediaRecordMO *> *)values;
- (void)removeRecords:(NSSet<CVMediaRecordMO *> *)values;

@end

NS_ASSUME_NONNULL_END
