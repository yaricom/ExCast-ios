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

#import "CastContainerController.h"
#import "CastDeviceController.h"
#import "CastUpNextView.h"
#import "NotificationConstants.h"

#import <GoogleCast/GoogleCast.h>

static const NSInteger kCastContainerUpNextDisplayHeight = 55;

@interface CastContainerController ()
@property (weak, nonatomic) IBOutlet UIView *containerView;
@property (weak, nonatomic) IBOutlet CastUpNextView *upnextView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *upnextHeight;
@end

@implementation CastContainerController

- (void)viewDidLoad {
  [super viewDidLoad];

  [_upnextView.playButton addTarget:self
                             action:@selector(onSkipToNextItem:)
                   forControlEvents:UIControlEventTouchUpInside];
  [_upnextView.stopButton addTarget:self
                             action:@selector(onStopAutoplay:)
                   forControlEvents:UIControlEventTouchUpInside];

  // Set initial state based on current preload.
  [self preloadStatusChange];
}

- (void)viewWillAppear:(BOOL)animated {
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(preloadStatusChange)
                                               name:kCastPreloadStatusChangeNotification
                                             object:nil];

}

- (void)viewWillDisappear:(BOOL)animated {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [super viewWillDisappear:animated];
}

- (instancetype)initWithViewController:(UIViewController *)viewController {
  self = [super init];
  if (self) {
    [self addChildViewController:viewController];
    [self.containerView addSubview:viewController.view];
    [viewController didMoveToParentViewController:self];
  }
  return self;
}

/**
 *  Respond to changes in preload status by hiding or showing the up next view.
 */
- (void)preloadStatusChange {
  GCKMediaQueueItem *preload = [CastDeviceController sharedInstance].preloadingItem;
  if (!preload) {
    [self hideUpNext];
  } else {
    _upnextView.item = preload;
    [self showUpNext];
  }
}

- (void)hideUpNext {
  _upnextView.hidden = YES;
  _upnextHeight.constant = 0;
}

- (void)showUpNext {
  _upnextView.hidden = NO;
  _upnextHeight.constant = kCastContainerUpNextDisplayHeight;
}

- (void)onSkipToNextItem:(UIView *)sender {
  [[CastDeviceController sharedInstance].mediaControlChannel queueNextItem];
}

- (void)onStopAutoplay:(UIView *)sender {
  CastDeviceController *castDeviceController = [CastDeviceController sharedInstance];
  NSMutableArray *ids = [NSMutableArray array];
  GCKMediaStatus *mediaStatus = castDeviceController.mediaControlChannel.mediaStatus;
  NSInteger count = [mediaStatus queueItemCount];

  BOOL foundCurrent = NO;
  for (NSInteger i = 0; i < count; ++i) {
    GCKMediaQueueItem *item = [mediaStatus queueItemAtIndex:i];
    if (foundCurrent) {
      [ids addObject:@(item.itemID)];
    } else if (item.itemID == mediaStatus.currentItemID) {
      foundCurrent = YES;
    }
  }

  [castDeviceController.mediaControlChannel queueRemoveItemsWithIDs:ids];
  // Optimistically hide the up next view.
  [self hideUpNext];
}

@end
