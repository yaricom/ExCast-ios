//
//  PersistentMediaListModel.m
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/3/16.
//

#import "PersistentMediaListModel.h"

#define kNotifyStep 10

@interface PersistentMediaListModel(private)
    + (NSURL*) pathToMediaFile;
@end

@implementation PersistentMediaListModel {
    /** Storage for the list of Media objects. */
    NSMutableArray *_medias;
}

- (id)init {
    self = [super init];
    if (self) {
        _medias = [NSMutableArray array];
    }
    return self;
}

- (void)loadMedia:(void (^)(BOOL final))callbackBlock {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *urls = [NSArray arrayWithContentsOfURL:[PersistentMediaListModel pathToMediaFile]];
        // start loading
        if (urls) {
            [self loadFrom:urls atIndex:0 withCallback:callbackBlock];
        }
    });
}

- (void) loadFrom:(NSArray *)urls atIndex:(NSUInteger)index withCallback:(void (^)(BOOL final))callbackBlock {
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

- (Media *)mediaAtIndex:(NSInteger)index {
    return (Media *)[_medias objectAtIndex:index];
}

- (void) removeMediaAtIndex:(NSInteger) index {
    [_medias removeObjectAtIndex:index];
    
    [self saveMediaList];
}

- (void) addMedia:(Media *) media {
    [_medias addObject:media];
    
    [self saveMediaList];
}

- (int)indexOfMediaByTitle:(NSString *)title {
    for (int i = 0; i < self.numberOfMediaLoaded; i++) {
        Media *media = [self mediaAtIndex:i];
        if ([media.title isEqualToString:title]) {
            return i;
        }
    }
    return -1;
}

- (void) saveMediaList {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *urls = [NSMutableArray arrayWithCapacity:[_medias count]];
        for (ExMedia *m in _medias) {
            [urls addObject:m.pageUrl.absoluteString];
        }
        
        NSURL* mediaList = [PersistentMediaListModel pathToMediaFile];
        
        [urls writeToURL:mediaList atomically:YES];
        
        NSLog(@"Media list saved to: %@", [mediaList absoluteString]);
    });
}

+ (NSURL*) pathToMediaFile {
    NSFileManager *fileManger = [NSFileManager defaultManager];
    
    NSURL *docsDirectory = [[fileManger URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
    return [docsDirectory URLByAppendingPathComponent:@"media.list"];
}

@end
