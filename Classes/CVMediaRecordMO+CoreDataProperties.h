//
//  CVMediaRecordMO+CoreDataProperties.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 6/23/16.
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
@property (nullable, nonatomic, retain) NSNumber *neverPlayed;
@property (nullable, nonatomic, retain) NSString *pageUrl;
@property (nullable, nonatomic, retain) NSString *title;
@property (nullable, nonatomic, retain) NSNumber *valid;
@property (nullable, nonatomic, retain) NSString *thumbnailUrl;
@property (nullable, nonatomic, retain) NSString *mimeType;
@property (nullable, nonatomic, retain) NSOrderedSet<CVMediaTrack *> *tracks;
@property (nullable, nonatomic, retain) NSOrderedSet<CVGenreMO *> *genres;

@end

@interface CVMediaRecordMO (CoreDataGeneratedAccessors)

- (void)insertObject:(CVMediaTrack *)value inTracksAtIndex:(NSUInteger)idx;
- (void)removeObjectFromTracksAtIndex:(NSUInteger)idx;
- (void)insertTracks:(NSArray<CVMediaTrack *> *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeTracksAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInTracksAtIndex:(NSUInteger)idx withObject:(CVMediaTrack *)value;
- (void)replaceTracksAtIndexes:(NSIndexSet *)indexes withTracks:(NSArray<CVMediaTrack *> *)values;
- (void)addTracksObject:(CVMediaTrack *)value;
- (void)removeTracksObject:(CVMediaTrack *)value;
- (void)addTracks:(NSOrderedSet<CVMediaTrack *> *)values;
- (void)removeTracks:(NSOrderedSet<CVMediaTrack *> *)values;

- (void)insertObject:(CVGenreMO *)value inGenresAtIndex:(NSUInteger)idx;
- (void)removeObjectFromGenresAtIndex:(NSUInteger)idx;
- (void)insertGenres:(NSArray<CVGenreMO *> *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeGenresAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInGenresAtIndex:(NSUInteger)idx withObject:(CVGenreMO *)value;
- (void)replaceGenresAtIndexes:(NSIndexSet *)indexes withGenres:(NSArray<CVGenreMO *> *)values;
- (void)addGenresObject:(CVGenreMO *)value;
- (void)removeGenresObject:(CVGenreMO *)value;
- (void)addGenres:(NSOrderedSet<CVGenreMO *> *)values;
- (void)removeGenres:(NSOrderedSet<CVGenreMO *> *)values;

@end

NS_ASSUME_NONNULL_END
