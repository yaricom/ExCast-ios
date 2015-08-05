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

#import "AlertHelper.h"

#import <objc/runtime.h>

@interface AlertHelperAction : NSObject
@property(nonatomic, strong) void(^handler)();
@property(nonatomic, copy) NSString *title;
@end

@implementation AlertHelperAction
@end

@interface AlertHelper () <UIAlertViewDelegate>

@end

@implementation AlertHelper {
  NSMutableArray *_handlers;
  NSMutableDictionary *_indexedHandlers;
}

- (instancetype)init {
  if ((self = [super init])) {
    _handlers = [NSMutableArray array];
  }
  return self;
}

- (void)addAction:(NSString *)title handler:(void(^)())handler {
  AlertHelperAction *action = [[AlertHelperAction alloc] init];
  action.title = title;
  action.handler = handler;
  [_handlers addObject:action];
}

- (void)showOnController:(UIViewController *)parent
              sourceView:(UIView *)sourceView {
  if ([UIAlertController class]) {
    // iOS 8+ approach.
    UIAlertController *controller =
        [UIAlertController alertControllerWithTitle:_title
                                            message:_message
                                     preferredStyle:UIAlertControllerStyleActionSheet];

    for (AlertHelperAction *action in _handlers) {
      UIAlertAction *alertAction = [UIAlertAction actionWithTitle:action.title
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *unused) {
                                                            action.handler();
                                                          }];
      [controller addAction:alertAction];
    }

    if (_cancelButtonTitle) {
      UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:_cancelButtonTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [controller dismissViewControllerAnimated:YES completion:nil];
      }];
      [controller addAction:cancelAction];
    }

    // Present the controller in the right location, on iPad. On iPhone, it always displays at the
    // bottom of the screen.
    UIPopoverPresentationController *presentationController =
        [controller popoverPresentationController];
    presentationController.sourceView = sourceView;
    presentationController.sourceRect = sourceView.bounds;
    presentationController.permittedArrowDirections = 0;

    [parent presentViewController:controller animated:YES completion:nil];

  } else {
    // iOS 7 and below.
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:_title
                                                        message:_message
                                                       delegate:self
                                              cancelButtonTitle:_cancelButtonTitle
                                              otherButtonTitles:nil];

    _indexedHandlers = [NSMutableDictionary dictionaryWithCapacity:_handlers.count];
    for (AlertHelperAction *action in _handlers) {
      NSInteger position = [alertView addButtonWithTitle:action.title];
      _indexedHandlers[@(position)] = action;
    }
    [alertView show];

    // Hold onto this AlertHelper until the UIAlertView is dismissed. This ensures that the delegate
    // is not released (as UIAlertView usually only holds a weak reference to us).
    static char kAlertHelperKey;
    objc_setAssociatedObject(alertView, &kAlertHelperKey, self, OBJC_ASSOCIATION_RETAIN);
  }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
  AlertHelperAction *action = _indexedHandlers[@(buttonIndex)];
  _indexedHandlers = nil;  // clicked something, clear handlers
  if (action != nil) {
    action.handler();
  }
}

- (void)alertViewCancel:(UIAlertView *)alertView {
  _indexedHandlers = nil;
}

@end
