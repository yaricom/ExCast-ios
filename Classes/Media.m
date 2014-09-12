// Copyright 2014 Google Inc. All Rights Reserved.
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

#import "Media.h"
#import <GoogleCast/GCKMediaTrack.h>

#define KEY_TITLE @"title"
#define KEY_DESCRIP @"subtitle"
#define KEY_URL @"sources"
#define KEY_MIME @"mimeType"
#define KEY_THUMBNAIL @"image-480x270"
#define KEY_POSTER @"image-780x1200"
#define KEY_OWNER @"studio"
#define KEY_TRACKS @"tracks"

#define KEY_TRACK_ID @"id"
#define KEY_TRACK_TYPE @"type"
#define KEY_TRACK_SUBTYPE @"subtype"
#define KEY_TRACK_URL @"contentId"
#define KEY_TRACK_NAME @"name"
#define KEY_TRACK_MIME @"name"
#define KEY_TRACK_LANGUAGE @"language"

@implementation Media

- (id)initWithExternalJSON:(NSDictionary *)jsonAsDict {
  self = [super init];
  if (self) {
    _title = [jsonAsDict objectForKey:KEY_TITLE];
    _descrip = [jsonAsDict objectForKey:KEY_DESCRIP];
    _mimeType = @"video/mp4";
    _subtitle = [jsonAsDict objectForKey:KEY_OWNER];
    _URL = [NSURL URLWithString:[[jsonAsDict objectForKey:KEY_URL]
                                 objectAtIndex:0]];
    _thumbnailURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",
        MEDIA_URL_BASE, [jsonAsDict objectForKey:KEY_THUMBNAIL]]];
    _posterURL = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@",
        MEDIA_URL_BASE, [jsonAsDict objectForKey:KEY_POSTER]]];
    if ([jsonAsDict objectForKey:KEY_TRACKS]) {
      NSArray *source = [jsonAsDict objectForKey:KEY_TRACKS];
      NSMutableArray *tracks = [NSMutableArray arrayWithCapacity:[source count]];
      for(int i = 0; i < [source count]; i++) {
        NSDictionary *sourceTrack = [jsonAsDict objectForKey:KEY_TRACKS][i];
        GCKMediaTrackType type = [self trackTypeFrom:[sourceTrack objectForKey:KEY_TRACK_TYPE]];
        GCKMediaTextTrackSubtype subtype =
            [self trackSubtypeFrom:[sourceTrack objectForKey:KEY_TRACK_SUBTYPE]];
        NSInteger identifier = [[sourceTrack objectForKey:KEY_TRACK_ID] intValue];
        GCKMediaTrack *track =
            [[GCKMediaTrack alloc] initWithIdentifier:identifier
                                    contentIdentifier:[sourceTrack objectForKey:KEY_TRACK_URL]
                                          contentType:@"text/vtt"
                                                 type:type
                                          textSubtype:subtype
                                                 name:[sourceTrack objectForKey:KEY_TRACK_NAME]
                                         languageCode:[sourceTrack objectForKey:KEY_TRACK_LANGUAGE]
                                           customData:nil];
        tracks[i] = track;
      }
      _tracks = [NSArray arrayWithArray:tracks];
    }
  }
  return self;

}

- (GCKMediaTrackType)trackTypeFrom:(NSString *)string {
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

- (GCKMediaTextTrackSubtype)trackSubtypeFrom:(NSString *)string {
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

+ (id)mediaFromExternalJSON:(NSDictionary *)jsonAsDict {
  Media *newMedia = [[Media alloc] initWithExternalJSON:jsonAsDict];
  return newMedia;
}

@end