// Copyright 2015 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <GoogleCast/GCKImage.h>
#import <GoogleCast/GCKMediaMetadata.h>
#import <GoogleCast/GCKMediaTextTrackStyle.h>
#import <GoogleCast/GCKMediaTrack.h>

#import "CastViewController.h"
#import "GCKMediaInformation+LocalMedia.h"
#import "CVMediaTrack.h"

@implementation GCKMediaInformation (LocalMedia)

+ (GCKMediaInformation *)mediaInformationFromTrack:(CVMediaTrack *)media forRecord: (CVMediaRecordMO *)record {
    GCKMediaMetadata *metadata = [[GCKMediaMetadata alloc] initWithMetadataType:GCKMediaMetadataTypeMovie];
    if (record.title) {
        [metadata setString:record.title forKey:kGCKMetadataKeyTitle];
    }
    
    if (media.name) {
        [metadata setString:media.name forKey:kGCKMetadataKeySubtitle];
    }
    
    if ([record thumbnailURL]) {
        [metadata addImage: [[GCKImage alloc] initWithURL: [record thumbnailURL] width:200 height:100]];
        [metadata setString: record.thumbnailUrl forKey: kCastComponentPosterURL];
    }
    
    GCKMediaInformation *mi =
    [[GCKMediaInformation alloc] initWithContentID: media.address
                                        streamType: GCKMediaStreamTypeNone
                                       contentType: record.mimeType
                                          metadata: metadata
                                    streamDuration: 0
                                       mediaTracks: nil
                                    textTrackStyle: [GCKMediaTextTrackStyle createDefault]
                                        customData: nil];
    return mi;
}

+ (GCKMediaTrackType)trackTypeFrom:(NSString *)string {
    if ([string isEqualToString:@"audio"]) {
        return GCKMediaTrackTypeAudio;
    }
    if ([string isEqualToString:@"text"]) {
        return GCKMediaTrackTypeText;
    }
    if ([string isEqualToString:@"video"]) {
        return GCKMediaTrackTypeVideo;
    }
    return GCKMediaTrackTypeUnknown;
}

+ (GCKMediaTextTrackSubtype)trackSubtypeFrom:(NSString *)string {
    if ([string isEqualToString:@"captions"]) {
        return GCKMediaTextTrackSubtypeCaptions;
    }
    if ([string isEqualToString:@"chapters"]) {
        return GCKMediaTextTrackSubtypeChapters;
    }
    if ([string isEqualToString:@"descriptions"]) {
        return GCKMediaTextTrackSubtypeDescriptions;
    }
    if ([string isEqualToString:@"metadata"]) {
        return GCKMediaTextTrackSubtypeMetadata;
    }
    if ([string isEqualToString:@"subtitles"]) {
        return GCKMediaTextTrackSubtypeSubtitles;
    }
    
    return GCKMediaTextTrackSubtypeUnknown;
}

@end
