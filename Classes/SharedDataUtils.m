//
//  SharedDataUtils.m
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/4/16.
//

#import "SharedDataUtils.h"

// The DB related
static NSString * const kMediaRecordsDBFile = @"mediaRecords";
static NSString * const kMediaRecordsDBFileExtension = @"sqlite";

// The shared data group identifier
static NSString * const kCCSharedAppGroupIdentifier = @"group.ua.nologin.ChromeCast.ExCast";

@implementation SharedDataUtils

+ (NSURL*) pathToMediaRecordsDB {
    NSURL *dbDirectory = [SharedDataUtils sharedGroupDataDirectory];
    return [dbDirectory URLByAppendingPathComponent:
            [NSString stringWithFormat:@"%@.%@", kMediaRecordsDBFile, kMediaRecordsDBFileExtension]];
}

+ (NSURL*) pathToMediaFile {
    NSURL *docsDirectory = [SharedDataUtils sharedGroupDataDirectory];
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
