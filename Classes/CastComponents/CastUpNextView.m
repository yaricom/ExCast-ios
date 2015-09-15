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

#import "CastUpNextView.h"
#import "CastViewController.h"
#import "SimpleImageFetcher.h"

#import <GoogleCast/GoogleCast.h>

@interface CastUpNextView ()
@property (nonatomic) IBOutlet UIImageView *image;
@property (nonatomic) IBOutlet UILabel *title;
@property (nonatomic) UIView *subview;

@end

@implementation CastUpNextView

- (void)setItem:(GCKMediaQueueItem *)item {
  _item = item;
  if (!item) {
    self.hidden = YES;
    return;
  }

  _title.text = [item.mediaInformation.metadata stringForKey:kGCKMetadataKeyTitle];
  self.hidden = NO;

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSString *posterURL = [item.mediaInformation.metadata stringForKey:kCastComponentPosterURL];
    if (posterURL) {
      UIImage *image =
        [UIImage imageWithData:
            [SimpleImageFetcher getDataFromImageURL:[NSURL URLWithString:posterURL]]];

      dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"Loaded thumbnail image");
        self.image.image = image;
        [self setNeedsLayout];
      });
    }
  });
}

@end
