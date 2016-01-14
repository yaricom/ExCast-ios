//
//  ExMedia.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/3/16.
//

#import <Foundation/Foundation.h>

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
@property(nonatomic, strong) NSArray *__nullable tracks;

/**
 *  Creates a Media object given a page URL.
 *
 *  @param url The media page URL
 *  @param completeBlock The completion handler
 *  @param errorBlock The error block or nil
 */
+ (void) mediaFromExURL:(NSURL *__nonnull)url
        withCompletion:(void (^__nonnull)(ExMedia* __nullable media, NSError * __nullable error))completeBlock;

/**
 *  Invoked to reload remote media info
 *  @param completeBlock The completion handler
 */
- (void) reloadWithCompletion:(void (^__nonnull)(NSError * __nullable error))completeBlock;

@end
