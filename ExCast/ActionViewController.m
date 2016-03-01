//
//  ActionViewController.m
//  ExCast
//
//  Created by Iaroslav Omelianenko on 1/4/16.
//

#import "ActionViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>

#import "SharedDataUtils.h"
#import "ExMedia.h"
#import "CVCoreDataController.h"

#import "GenreSelectorTableViewController.h"

#define kLabelCellIdentifier        @"labelCell"
#define kGenreCellIdentifier        @"genreCell"
#define kTextFieldCellIdentifier    @"textFieldCell"


static NSString * const kSelectedMainGenreNotification = @"kSelectedMainGenreNotification";
static NSString * const kSelectedSubGenreNotification = @"kSelectedSubGenreNotification";

static int const kMainGenreRow = 2;
static int const kSubGenreRow = 3;


@interface ActionViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *doneBarBtn;

// the page URL if any
@property (strong, nonatomic) NSURL *pageUrl;
// the page address
@property (strong, nonatomic) NSString *pageUrlText;
// the media object associated with page
@property (strong, nonatomic) ExMedia *media;
// the movie description
@property (strong, nonatomic) NSString *movieDetails;

// the section titles
@property (strong, nonatomic) NSArray<NSString*> *sectionTitles;
// the genres titles
@property (strong, nonatomic) NSArray<NSString*> *genres;
// the main genre index
@property (assign, nonatomic) NSInteger mainGenreIndex;
// the sub genre index
@property (assign, nonatomic) NSInteger subGenreIndex;

// the core data controller
@property (strong, nonatomic) CVCoreDataController *dataControler;

@end

@implementation ActionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.dataControler = [[CVCoreDataController alloc] init];
    
    // initialize section titles
    self.sectionTitles = @[NSLocalizedString(@"Web Page", nil),
                           NSLocalizedString(@"Movie Title", nil),
                           NSLocalizedString(@"Movie Main Genre", nil),
                           NSLocalizedString(@"Movie Sub Genre", nil),
                           NSLocalizedString(@"Movie Description", nil)];
    
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
                        // get movie URL
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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // register genre selection notification listeners
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(mainGenreSelected:)
                                                 name:kSelectedMainGenreNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(subGenreSelected:)
                                                 name:kSelectedSubGenreNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    GenreSelectorTableViewController *vc = (GenreSelectorTableViewController *)[segue destinationViewController];
    vc.genres = self.genres;
    NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
    if (selectedIndexPath.row == kMainGenreRow) {
        vc.selectedIndex = self.mainGenreIndex;
        vc.selectNotification = kSelectedMainGenreNotification;
    } else {
        vc.selectedIndex = self.subGenreIndex;
        vc.selectNotification = kSelectedSubGenreNotification;
    }
}

#pragma mark - Actions processing
- (IBAction)cancel:(id)sender {
    // Return any edited content to the host app.
    // This template doesn't do anything, so we just echo the passed in items.
    [self.extensionContext completeRequestReturningItems:self.extensionContext.inputItems completionHandler:nil];
}

- (IBAction)done:(id)sender {
    // save media record
    [[self.dataControler saveAsyncWithURL: self.pageUrl
                                    title: self.media.title
                              description: self.movieDetails
                                    genre: self.genres[self.mainGenreIndex]
                                 subGenre: self.genres[self.subGenreIndex]]
     continueWithBlock:^id _Nullable(BFTask * _Nonnull task) {
         // check for error
         if (task.error) {
             NSLog(@"Failed to save media record, %@\n%@", [task.error localizedDescription], [task.error userInfo]);
             
             // show error alert
             [self showAlertWithTitle:NSLocalizedString(@"Failed to save media record", nil)
                              message:[task.error localizedDescription]
                    completionHandler:^{
                        // close screen
                        [self closeScreen];
                    }];
         } else {
             // close screen
             [self closeScreen];
         }
         
         return nil;
     }];
}

// method to close extension screen
- (void) closeScreen {
    [self.extensionContext completeRequestReturningItems:self.extensionContext.inputItems completionHandler:nil];
}

#pragma mark - Table view
- (NSString*)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section < self.sectionTitles.count) {
        return self.sectionTitles[section];
    } else {
        return nil;
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.media) {
        return self.sectionTitles.count;
    } else {
        return 1;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section < self.sectionTitles.count - 1) {
        return 44;
    } else {
        return 100;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    if (indexPath.section < kMainGenreRow) {
        // page address and movie title
        cell = [tableView dequeueReusableCellWithIdentifier:kLabelCellIdentifier];
        if (indexPath.section == 0) {
            if (self.pageUrlText) {
                cell.textLabel.text = self.pageUrlText;
            }
        } else if (self.media) {
            cell.textLabel.text = self.media.title;
        }
    } else if (indexPath.section <= kSubGenreRow) {
        // main/sub genres
        cell = [tableView dequeueReusableCellWithIdentifier:kGenreCellIdentifier];
        cell.textLabel.text = NSLocalizedString([self.genres objectAtIndex:indexPath.section == kMainGenreRow ?
                                                 self.mainGenreIndex : self.subGenreIndex], nil);
    } else if (self.media) {
        // description
        cell = [tableView dequeueReusableCellWithIdentifier:kTextFieldCellIdentifier];
        UITextView *textView = [cell viewWithTag:101];
        [textView setText:@""];
#warning implement keyboard show/hide
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == kMainGenreRow || indexPath.row == kSubGenreRow) {
        // invoke select genre screen
        [self performSegueWithIdentifier:@"selectGenreSegue" sender:self];
    }
}

#pragma mark - notification receivers
- (void) mainGenreSelected:(NSNotification *) notification {
    self.mainGenreIndex = [notification.userInfo[kSelectedIndexKey] integerValue];
    [self.tableView reloadData];
}

- (void) subGenreSelected:(NSNotification *) notification {
    self.subGenreIndex = [notification.userInfo[kSelectedIndexKey] integerValue];
    [self.tableView reloadData];
}

#pragma mark - private methods
- (void) setMoviePageUrl:(NSString *) urlStr {
    // check if this is Ex.ua page
    if ([urlStr containsString:@"ex.ua"]) {
        self.doneBarBtn.enabled = YES;
        self.pageUrlText = urlStr;
        self.pageUrl = [NSURL URLWithString:self.pageUrlText];
        [self loadPageDetails:self.pageUrl];
    } else {
        self.pageUrlText = NSLocalizedString(@"Only ex.ua pages supported", nil);
        
    }
    [self.tableView reloadData];
}

- (void) loadPageDetails: (NSURL*) pageUrl {
    [ExMedia mediaFromExURL:pageUrl withCompletion:^(ExMedia * _Nullable media, NSError * _Nullable error) {
        // read genres
        NSURL *gURL = [[NSBundle mainBundle] URLForResource:@"genres" withExtension:@"plist"];
        if (gURL) {
            self.genres = [NSArray arrayWithContentsOfURL:gURL];
        }
        // process media
        dispatch_async(dispatch_get_main_queue(), ^{
            if (media) {
                self.media = media;
                if ([self.media.tracks count] == 0) {
                    [self showAlertWithTitle:NSLocalizedString(@"No Movies Found", nil)
                                     message:NSLocalizedString(@"No link to the movies found on the page. Please check that provided page has any movie links!", nil)
                           completionHandler:^{
                               // just close
                               [self cancel:nil];
                           }];
                } else {
                    // refresh data view
                    [self.tableView reloadData];
                }
            } else if (error) {
                NSLog(@"Failed to load media details, %@\%@", [error localizedDescription], [error userInfo]);
                [self showAlertWithTitle:NSLocalizedString(@"Failed to read page! Please check that page is availabe and try again later.", nil)
                                 message:[error localizedDescription]
                       completionHandler:^{
                           // just close
                           [self cancel:nil];
                       }];
            }
        });
    }];
}

- (void) showAlertWithTitle:(NSString *) title
                    message:(NSString *) message
          completionHandler:(void (^__nonnull)()) block {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle: title
                                                                   message: message
                                                            preferredStyle: UIAlertControllerStyleAlert];
    UIAlertAction* defaultAction = [UIAlertAction actionWithTitle: NSLocalizedString(@"OK", nil)
                                                            style: UIAlertActionStyleDefault
                                                          handler: ^(UIAlertAction * action) {
                                                              // invoke block
                                                              block();
                                                          }];
    
    [alert addAction:defaultAction];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
