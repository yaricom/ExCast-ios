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

@end
