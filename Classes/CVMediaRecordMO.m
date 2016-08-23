//
//  CVMediaRecordMO.m
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 2/29/16.
//

#import "CVMediaRecordMO.h"
#import "CVGenreMO.h"

NSString* const kMediaRecordEntityName = @"MediaRecord";

@implementation CVMediaRecordMO

- (BOOL) hasBeenSeen {
    return !self.neverPlayed.boolValue;
}

- (NSURL *) pageURL {
    return [NSURL URLWithString:self.pageUrl];
}

- (NSURL *) thumbnailURL {
    return [NSURL URLWithString:self.thumbnailUrl];
}

- (CVMediaTrack *) trackAtIndex: (NSInteger) index {
    if (index < self.tracks.count) {
        return [self.tracks objectAtIndex:index];
    }
    return nil;
}
@end
