//
//  ActionViewController.m
//  ExCast
//
//  Created by Iaroslav Omelianenko on 1/4/16.
//

#import "ActionViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

#import "SharedDataUtils.h"

@interface ActionViewController () <UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *doneBarBtn;

@property (strong, nonatomic) NSString *pageUrlText;

@end

@implementation ActionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // initialize table view
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    self.doneBarBtn.enabled = NO;
    
    // Get the item[s] we're handling from the extension context.
    for (NSExtensionItem *item in self.extensionContext.inputItems) {
        for (NSItemProvider *itemProvider in item.attachments) {
            if ([itemProvider hasItemConformingToTypeIdentifier:(NSString *)kUTTypePropertyList]) {
                // load item content
                [itemProvider loadItemForTypeIdentifier:(NSString *)kUTTypePropertyList options:nil completionHandler:^(id<NSSecureCoding>  _Nullable item, NSError * _Null_unspecified error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSDictionary *dictionary = (NSDictionary*) item;
                        NSString *urlStr = [[dictionary objectForKey:NSExtensionJavaScriptPreprocessingResultsKey] objectForKey:@"currentUrl"];
                        [self setMoviePageUrl:urlStr];
                    });
                }];
                break;
            }
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Actions processing
- (IBAction)cancel:(id)sender {
    // Return any edited content to the host app.
    // This template doesn't do anything, so we just echo the passed in items.
    [self.extensionContext completeRequestReturningItems:self.extensionContext.inputItems completionHandler:nil];
}

- (IBAction)done:(id)sender {
    [self.extensionContext completeRequestReturningItems:self.extensionContext.inputItems completionHandler:^(BOOL expired) {
        if (!expired) {
            // save page URL
            NSMutableArray<NSString *> *urls = [NSMutableArray arrayWithContentsOfURL:[SharedDataUtils pathToMediaFile]];
            if (!urls) {
                urls = [NSMutableArray arrayWithCapacity:1];
            }
            [urls addObject:self.pageUrlText];
            
            [urls writeToURL:[SharedDataUtils pathToMediaFile] atomically:YES];
            
            NSLog(@"Media list saved to: %@", [[SharedDataUtils pathToMediaFile] absoluteString]);
        }
    }];
}

#pragma mark - Table view
- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return NSLocalizedString(@"Page address", nil) ;
    } else {
        return nil;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"urlCell"];
    if (self.pageUrlText) {
        cell.textLabel.text = self.pageUrlText;
    }
    
    return cell;
}

#pragma mark - private methods
- (void) setMoviePageUrl:(NSString *) urlStr {
    // check if this is Ex.ua page
    if ([urlStr containsString:@"ex.ua"]) {
        self.doneBarBtn.enabled = YES;
        self.pageUrlText = urlStr;
    } else {
        self.pageUrlText = NSLocalizedString(@"Only ex.ua pages supported", nil);
        
    }
    [self.tableView reloadData];
}

@end
