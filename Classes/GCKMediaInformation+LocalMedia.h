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

#import "ExMedia.h"

#import <GoogleCast/GCKMediaInformation.h>

/**
 * Category to convert the Media objects we are using for local storage to a
 * GCKMediaInformation object suitable for use elsewhere.
 */
@interface GCKMediaInformation (LocalMedia)

+ (GCKMediaInformation *)mediaInformationFromLocalMedia:(ExMedia *)media;

@end
