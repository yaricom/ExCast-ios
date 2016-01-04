//
//  SharedDataUtils.m
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/4/16.
//

#import "SharedDataUtils.h"

// The shared data group identifier
static NSString * const kCCSharedAppGroupIdentifier = @"group.dk.whiterock.friendsnotifier.iwatch";

@implementation SharedDataUtils

+ (NSURL*) pathToMediaFile {
    NSFileManager *fileManger = [NSFileManager defaultManager];
    
    NSURL *docsDirectory = [[fileManger URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
    return [docsDirectory URLByAppendingPathComponent:@"media.list"];
}

+ (NSURL*) sharedGroupDataDirectory {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSURL *dirPath = [fm containerURLForSecurityApplicationGroupIdentifier:kCCSharedAppGroupIdentifier];
    if (dirPath == nil) {
        NSLog(@"Failed to create shared data container folder!");
    }
    return dirPath;
}

@end
