//
//  Media+Ex.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/2/16.
//

#import <UIKit/UIKit.h>

#import "Media.h"

/**
 * Defines a media object that can be played back on Chromcast device and able to read its values from ex.ua.
 */
@interface Media(Ex_ua)

/**
 *  Creates a Media object given a page URL.
 *
 *  @param url The media page URL
 *  @param completeBlock The completion handler
 *  @param errorBlock The error block or nil
 *
 *  @return Media
 */
+ (void)mediaFromExURL:(NSURL *__nonnull)url
        withCompletion:(void (^__nonnull)(Media* __nullable media, NSError * __nullable error))completeBlock;


@end
