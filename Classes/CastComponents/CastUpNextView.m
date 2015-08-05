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
@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UILabel *title;
@property (strong, nonatomic) UIView *subview;

@end

@implementation CastUpNextView

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self sharedInit];
  }
  return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self sharedInit];
  }
  return self;
}

- (void)sharedInit {
  NSArray *objects = [[NSBundle bundleForClass:[self class]] loadNibNamed:@"CastUpNextView"
                                                   owner:self
                                                 options:nil];
  self.subview = [objects objectAtIndex:0];
  _subview.frame = self.bounds;
  _subview.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

  [self addSubview:_subview];
}

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
