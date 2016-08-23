//
//  ExMediaTrack.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/14/16.
//

#import <Foundation/Foundation.h>

/**
 * The Media track associated with specific Media on Ex.ua site
 */
@interface ExMediaTrack : NSObject

@property(nonatomic, assign) NSInteger identifier;
@property(nonatomic, copy) NSString *mimeType;
@property(nonatomic, copy) NSString *name;
@property(nonatomic, copy) NSURL *url;

@end
