//
//  SharedDataUtils.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/4/16.
//

#import <Foundation/Foundation.h>

// The DB file name
static NSString * const kMediaRecordsDBFile;
// The DB file name extension
static NSString * const kMediaRecordsDBFileExtension;

/**
 * The utilities to manage access to shared data between app and extension
 */
@interface SharedDataUtils : NSObject

/**
 * Returns path to the shared media records Data Base
 */
+ (NSURL*) pathToMediaRecordsDB;

/**
 * Returns path to the media list file stored as .PLIST
 */
+ (NSURL*) pathToMediaFile;

/**
 * Returns path to the directory shared among group participants
 */
+ (NSURL*) sharedGroupDataDirectory;

@end
