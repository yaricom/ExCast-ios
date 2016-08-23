//
//  MediaTracksTableViewController.h
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 1/14/16.
//

#import <UIKit/UIKit.h>

#import "CVMediaRecordMO.h"

@interface MediaTracksTableViewController : UITableViewController

// The media holder object
@property(strong, nonatomic) CVMediaRecordMO *mediaToPlay;

@end
