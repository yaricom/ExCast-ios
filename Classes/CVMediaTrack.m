//
//  CVMediaTrack.m
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 6/23/16.
//  Copyright © 2016 Google inc. All rights reserved.
//

#import "CVMediaTrack.h"
#import "CVMediaRecordMO.h"

NSString* const kMediaTrackEntityName = @"MediaTrack";

@implementation CVMediaTrack

- (NSURL *) trackURL {
    return [NSURL URLWithString:self.address];
}

@end
