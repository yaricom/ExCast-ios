//
//  GenreSelectorTableViewController.m
//  CastVideos
//
//  Created by Iaroslav Omelianenko on 3/1/16.
//

#import "GenreSelectorTableViewController.h"

static NSString * const kSelectedIndexKey = @"kSelectedIndexKey";

@interface GenreSelectorTableViewController ()

@end

@implementation GenreSelectorTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // pre select
    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:self.selectedIndex inSection:0]
                                animated:YES
                          scrollPosition:UITableViewScrollPositionMiddle];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.genres count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"labelCell" forIndexPath:indexPath];
    
    if (indexPath.row < [self.genres count]) {
        cell.textLabel.text = [self.genres objectAtIndex:indexPath.row];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // notify about selection
    if (self.delegate) {
        [self.delegate onGenreSelected:indexPath.row forType:self.genreType];
    }
    
    // close
    [self cancelAction:nil];
}

#pragma mark - Navigation

- (IBAction)cancelAction:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

@end
