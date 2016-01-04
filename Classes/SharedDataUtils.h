//
//  SharedDataUtils.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/4/16.
//

#import <Foundation/Foundation.h>

/**
 * The utilities to manage access to shared data between app and extension
 */
@interface SharedDataUtils : NSObject

+ (NSURL*) pathToMediaFile;

+ (NSURL*) sharedGroupDataDirectory;

@end
