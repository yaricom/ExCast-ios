//
//  Media+Ex.m
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/2/16.
//
#import <HTMLReader/HTMLReader.h>
#import <GoogleCast/GoogleCast.h>

#import "Media+Ex.h"

@implementation Media(Ex_ua)

+ (void)mediaFromExURL:(NSURL *__nonnull)url
        withCompletion:(void (^__nonnull)(Media* __nullable media, NSError * __nullable error))completeBlock {
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
                    Media *m = [[Media alloc] initWithHTMLDocument:home];
                    completeBlock(m, nil);
                }] resume];
}

- (id)initWithHTMLDocument:(HTMLDocument *) document {
    self = [super init];
    if (self) {
        HTMLElement *h1 = [document firstNodeMatchingSelector:@"h1"];
        self.title = [h1 textContent];
        
        // get thumbnail URL
        NSArray *imgs = [document nodesMatchingSelector:@"img"];
        for (HTMLElement *img in imgs) {
            // find appropriate URL
            NSString *alt = [img.attributes objectForKey:@"alt"];
            if (alt && [alt isEqualToString:self.title]) {
                self.thumbnailURL = [NSURL URLWithString:[img.attributes objectForKey:@"src"]];
                break;
            }
        }
        
        // get media URL
        NSArray *scripts = [document nodesMatchingSelector:@"script"];
        for (HTMLElement *node in scripts) {
            NSURL *url = [self findMediaURLinElement:node];
            if (url) {
                self.URL = url;
                break;
            }
        }
    }
    return self;
}

- (NSURL *)findMediaURLinElement:(HTMLElement*) script {
    NSString *text = [script textContent];
    __block NSURL *url = nil;
    if ([text containsString:@"player_list"]) {
        // extract video URL
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
                        // no need to enumerate
                        *stop = YES;
                        
                        // get URL
                        url = [NSURL URLWithString:[dict objectForKey:@"url"]];
                    }
                }
            }
        }];
    }
    return url;
}

@end
