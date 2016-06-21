//
//  PersistentMediaListModel.m
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/3/16.
//

#import "PersistentMediaListModel.h"

#import "SharedDataUtils.h"
#import "CVMediaRecordMO.h"

#define kNotifyStep 10

@interface PersistentMediaListModel(private)

@end

@implementation PersistentMediaListModel {
    /** Storage for the list of Media objects. */
    NSMutableArray<ExMedia *> *_medias;
    // The core data manager
    CVCoreDataController *_coreDataManager;
}

- (id) initWithCoreDataController: (CVCoreDataController *) coreDataManager {
    self = [super init];
    if (self) {
        _medias = [NSMutableArray array];
        _coreDataManager = coreDataManager;
    }
    return self;
}

- (void)loadMedia:(void (^)(BOOL final))callbackBlock {
    [_coreDataManager.listMediaRecordsAsync continueWithBlock:^id _Nullable(BFTask * _Nonnull task) {
        if (!task.faulted) {
            NSArray<CVMediaRecordMO *> *records = task.result;
            NSMutableArray<NSString *> *urls = [NSMutableArray arrayWithCapacity:task.result];
            for (CVMediaRecordMO *record in records) {
                [urls addObject:record.pageUrl];
            }
            if (urls && [urls count] > 0) {
                // clear current list
                [_medias removeAllObjects];
                // start loading media
                [self loadFrom:urls atIndex:0 withCallback:callbackBlock];
            } else {
                callbackBlock(YES);
            }
        } else {
            NSLog(@"Failed to load media records, reason: %@", task.error);
        }
        return nil;
    }];
    
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSLog(@"Load media list from: %@", [[SharedDataUtils pathToMediaFile] absoluteString]);
        // read data
        NSArray<NSString *> *urls = [NSArray arrayWithContentsOfURL:[SharedDataUtils pathToMediaFile]];
        if (urls && [urls count] > 0) {
            // clear current list
            [_medias removeAllObjects];
            // start loading media
            [self loadFrom:urls atIndex:0 withCallback:callbackBlock];
        } else {
            callbackBlock(YES);
        }
    });
}

- (void) loadFrom:(NSArray<NSString *> *)urls atIndex:(NSUInteger)index withCallback:(void (^)(BOOL final))callbackBlock {
    [ExMedia mediaFromExURL:[NSURL URLWithString:urls[index]] withCompletion:^(ExMedia * _Nullable media, NSError * _Nullable error) {
        // check for error
        if (error) {
            NSLog(@"Failed to load remote media, reason: %@", error);
        } else {
            // store
            [_medias addObject:media];
            // notify UI
            if (index % kNotifyStep || index == urls.count - 1) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    callbackBlock(index == urls.count - 1);
                });
            }
            
            // procceed further if appropriate
            if (index < urls.count - 1) {
                [self loadFrom:urls atIndex:index + 1 withCallback:callbackBlock];
            }
        }
    }];
}

- (int)numberOfMediaLoaded {
    return (int)_medias.count;
}

- (ExMedia *)mediaAtIndex:(NSInteger)index {
    return [_medias objectAtIndex:index];
}

- (void) removeMediaAtIndex:(NSInteger) index {
    [_medias removeObjectAtIndex:index];
    
    [self saveMediaList];
}

- (void) addMedia:(ExMedia *) media {
    [_medias addObject:media];
    
    [self saveMediaList];
}

- (void) saveMediaList {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray<NSString *> *urls = [NSMutableArray arrayWithCapacity:[_medias count]];
        for (ExMedia *m in _medias) {
            [urls addObject:m.pageUrl.absoluteString];
        }
        
        // write data
        [urls writeToURL:[SharedDataUtils pathToMediaFile] atomically:YES];

        NSLog(@"Media list saved to: %@", [[SharedDataUtils pathToMediaFile] absoluteString]);
    });
}

@end
