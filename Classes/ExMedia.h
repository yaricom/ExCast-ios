//
//  ExMedia.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/3/16.
//

#import <Foundation/Foundation.h>

@class ExMediaTrack;

/**
 * The media object able to read from Ex.ua
 */
@interface ExMedia : NSObject

@property (strong, nonatomic) NSURL*__nonnull pageUrl;
@property(nonatomic, copy) NSString *__nonnull title;
@property(nonatomic, copy) NSString *__nullable descrip;
@property(nonatomic, copy) NSString *__nonnull mimeType;
@property(nonatomic, copy) NSString *__nullable subtitle;
@property(nonatomic, strong) NSURL *__nonnull URL;
@property(nonatomic, strong) NSURL *__nullable thumbnailURL;
@property(nonatomic, strong) NSURL *__nullable posterURL;
@property(nonatomic, strong) NSArray<ExMediaTrack *> *__nullable tracks;

/*!
 Creates a Media object given a page URL.

 @param url The media page URL
 @param completeBlock The completion handler which will be invoked on main queue
 */
+ (void) mediaFromExURL:(NSURL *__nonnull)url
        withCompletion:(void (^__nonnull)(ExMedia* __nullable media, NSError * __nullable error))completeBlock;


@end
