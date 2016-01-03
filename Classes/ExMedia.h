//
//  ExMedia.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/3/16.
//

#import <Foundation/Foundation.h>

#import "Media.h"

/**
 * The media object able to read from Ex.ua
 */
@interface ExMedia : Media

@property (strong, nonatomic) NSURL*__nonnull pageUrl;

/**
 *  Creates a Media object given a page URL.
 *
 *  @param url The media page URL
 *  @param completeBlock The completion handler
 *  @param errorBlock The error block or nil
 */
+ (void)mediaFromExURL:(NSURL *__nonnull)url
        withCompletion:(void (^__nonnull)(ExMedia* __nullable media, NSError * __nullable error))completeBlock;

/**
 *  Creates a Media object given a page URL.
 *
 *  @param url The media page URL
 *  @param error The pointer to error holder
 */
+ (ExMedia *__nonnull)createFromExURL:(NSURL*__nonnull)url withError:(NSError *__nullable*__nullable) error;

@end
