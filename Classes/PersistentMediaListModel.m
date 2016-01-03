//
//  PersistentMediaListModel.m
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/3/16.
//

#import "PersistentMediaListModel.h"

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

- (void)loadMedia:(void (^)(void))callbackBlock {
#warning implement this
}

- (int)numberOfMediaLoaded {
    return (int)_medias.count;
}

- (Media *)mediaAtIndex:(int)index {
    return (Media *)[_medias objectAtIndex:index];
}

- (void) addMedia:(Media *) media {
    [_medias addObject:media];
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

@end
