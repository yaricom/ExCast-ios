//
//  ExMedia.m
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/3/16.
//
#import <HTMLReader/HTMLReader.h>
#import <GoogleCast/GoogleCast.h>

#import "ExMedia.h"

@interface mediaInfo : NSObject
@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) NSString *title;
@end

@implementation mediaInfo
@end

@implementation ExMedia

+ (void)mediaFromExURL:(NSURL *__nonnull)url
        withCompletion:(void (^__nonnull)(ExMedia* __nullable media, NSError * __nullable error))completeBlock {
    // Load a web page.
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:[NSURLRequest requestWithURL:url]
                completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                    // parse response
                    if (error) {
                        // error occured
                        completeBlock(nil, error);
                        return;
                    }
                    NSString *contentType = nil;
                    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                        NSDictionary *headers = [(NSHTTPURLResponse *)response allHeaderFields];
                        contentType = headers[@"Content-Type"];
                    }
                    HTMLDocument *home = [HTMLDocument documentWithData:data
                                                      contentTypeHeader:contentType];
                    ExMedia *m = [[ExMedia alloc] init];
                    [m loadFromHTMLDocument:home];
                    m.subtitle = [url absoluteString];
                    m.pageUrl = url;
                    completeBlock(m, nil);
                }] resume];
}

- (void) reloadWithCompletion:(void (^__nonnull)(NSError * __nullable error))completeBlock {
    // Load a web page.
    NSURLSession *session = [NSURLSession sharedSession];
    [[session dataTaskWithRequest:[NSURLRequest requestWithURL:self.pageUrl]
                completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                    // parse response
                    if (error) {
                        // error occured
                        completeBlock(error);
                        return;
                    }
                    NSString *contentType = nil;
                    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                        NSDictionary *headers = [(NSHTTPURLResponse *)response allHeaderFields];
                        contentType = headers[@"Content-Type"];
                    }
                    HTMLDocument *home = [HTMLDocument documentWithData:data
                                                      contentTypeHeader:contentType];
                    [self loadFromHTMLDocument:home];
                    completeBlock(nil);
                }] resume];
}

- (void)loadFromHTMLDocument:(HTMLDocument *) document {
    HTMLElement *h1 = [document firstNodeMatchingSelector:@"h1"];
    self.title = [h1 textContent];
    
    // get thumbnail URL
    NSArray *imgs = [document nodesMatchingSelector:@"img"];
    for (HTMLElement *img in imgs) {
        // find appropriate URL
        NSString *alt = [img.attributes objectForKey:@"alt"];
        if (alt && [alt isEqualToString:self.title]) {
            self.thumbnailURL = [NSURL URLWithString:[img.attributes objectForKey:@"src"]];
            self.posterURL = self.thumbnailURL;
            break;
        }
    }
    
    // get media URL
    NSArray *scripts = [document nodesMatchingSelector:@"script"];
    for (HTMLElement *node in scripts) {
        NSArray *medias = [self findMediaInElement:node];
        if (medias) {
            if (medias.count == 1) {
                // only one track found
                self.URL = [medias[0] url];
            } else {
                // read all tracks
            }

            break;
        }
    }
    
    self.mimeType = @"video/mp4";
}

- (NSArray *)findMediaInElement:(HTMLElement*) script {
    NSString *text = [script textContent];
    // extract media URLs
    NSMutableArray *urls = [NSMutableArray array];
    if ([text containsString:@"player_list"]) {
        // extract video URLs
        [text enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
            NSRange startRange = [line rangeOfString:@"player_list"];
            if (startRange.length > 0) {
                // found line
                NSUInteger start = [line rangeOfString:@"'"].location;
                NSUInteger end = [line rangeOfString:@"'"
                                             options:NSLiteralSearch
                                               range:NSMakeRange(start + 1, line.length - start - 1)].location;
                NSString *jsonStr = [NSString stringWithFormat:@"[%@]", [line substringWithRange:NSMakeRange(start + 1, end - start - 1)]];
                NSArray *array = [GCKJSONUtils parseJSON:jsonStr];
                for (NSDictionary *dict in array) {
                    // check object type
                    if ([[dict objectForKey:@"type"] isEqualToString:@"video"]) {
                        // get URL
                        [urls addObject: [NSURL URLWithString: [dict objectForKey:@"url"]]];
                    }
                }
                
                // no need to enumerate any further
                *stop = YES;
            }
        }];
    }
    // extract media names
    NSMutableArray *info = [NSMutableArray array];
    if ([text containsString:@"player_info"]) {
        [text enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) {
            NSRange startRange = [line rangeOfString:@"player_list"];
            if (startRange.length > 0) {
                // found line
                NSUInteger start = [line rangeOfString:@"("].location;
                NSUInteger end = [line rangeOfString:@")"
                                             options:NSLiteralSearch
                                               range:NSMakeRange(start + 1, line.length - start - 1)].location;
                NSString *jsonStr = [NSString stringWithFormat:@"[%@]", [line substringWithRange:NSMakeRange(start + 1, end - start - 1)]];
                NSArray *array = [GCKJSONUtils parseJSON:jsonStr];
                for (NSDictionary *dict in array) {
                    [info addObject:[dict objectForKey:@"title"]];
                }
                
                // no need to enumerate any further
                *stop = YES;
            }
        }];
    }
    // prepare results
    NSMutableArray *res = [NSMutableArray array];
    for (int i = 0; i < urls.count; i++) {
        // store
        mediaInfo *minfo = [[mediaInfo alloc] init];
        minfo.url = [urls objectAtIndex:i];
        if (i < info.count) {
            minfo.title = [info objectAtIndex:i];
        }
        if (! minfo.title) {
            minfo.title = [minfo.url absoluteString];
        }
        
        [res addObject:minfo];
    }
    
    return res;
}


@end
