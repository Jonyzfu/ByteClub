//
//  NotesViewController.m
//  ByteClub
//
//  Created by Charlie Fulton on 7/28/13.
//  Copyright (c) 2013 Razeware. All rights reserved.
//

#import "NotesViewController.h"
#import "DBFile.h"
#import "NoteDetailsViewController.h"
#import "Dropbox.h"

@interface NotesViewController ()<NoteDetailsViewControllerDelegate>

@property (nonatomic, strong) NSArray *notes;


@end

@implementation NotesViewController

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        // Returns a session with no persistent storage for caches, cookies, or credentials
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration ephemeralSessionConfiguration];
        
        // add Authentication HTTP header to configuration object
        [config setHTTPAdditionalHeaders:@{@"Authorization": [Dropbox apiAuthorizationHeader]}];
        
        // create the NSURLSession
        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self notesOnDropbox];
}

// list files found in the root dir of appFolder
- (void)notesOnDropbox
{
    // making an authenticated GET request to a particular URL
    NSURL *url = [Dropbox appRootURL];
    
    // Create a data task in order to perform a GET request to that URL
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithURL:url
                                                 completionHandler:^(NSData *data,
                                                                     NSURLResponse *response,
                                                                     NSError *error) {
                                                     if (!error) {
                                                         // cast the NSURLResponse to an NSHTTPURLResponse response so you can access to the statusCode property
                                                         NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
                                                         if (httpResp.statusCode == 200) {
                                                             NSError *jsonError;
                                                             
                                                             NSDictionary *notesJSON = [NSJSONSerialization JSONObjectWithData:data
                                                                                                                       options:NSJSONReadingAllowFragments
                                                                                                                         error:&jsonError];
                                                             NSMutableArray *notesFound = [[NSMutableArray alloc] init];
                                                             if (!jsonError) {
                                                                 // pull out the array of objects from the "contents" key and then iterate through the array
                                                                 // DBFile is a helper class that pulls out the information for a file from the JSON dictionary
                                                                 NSArray *contentsOfRootDirectory = notesJSON[@"contents"];
                                                                 
                                                                 for (NSDictionary *data in contentsOfRootDirectory) {
                                                                     if (![data[@"is_dir"] boolValue]) {
                                                                         DBFile *note = [[DBFile alloc] initWithJSONData:data];
                                                                         [notesFound addObject: note];
                                                                     }
                                                                 }
                                                                 [notesFound sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                                                                     return [obj1 compare:obj2];
                                                                 }];
                                                                 
                                                                 self.notes = notesFound;
                                                                 
                                                                 // make sure to update UIKit on the main thread
                                                                 dispatch_async(dispatch_get_main_queue(), ^{
                                                                     [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
                                                                     [self.tableView reloadData];
                                                                 });
                                                             }
                                                         }
                                                     }
                                                 }];
    
    // A task defaults to a suspected state, so you need to call the resume method to start it
    [dataTask resume];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return _notes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"NoteCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    DBFile *note = _notes[indexPath.row];
    cell.textLabel.text = [[note fileNameShowExtension:YES]lowercaseString];
    return cell;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UINavigationController *navigationController = segue.destinationViewController;
    NoteDetailsViewController *showNote = (NoteDetailsViewController*) [navigationController viewControllers][0];
    // NoteViewController is set as the NoteDetailsViewController's delegate.
    // NoteDetailsViewController can notify NoteViewController when user finishes editing a note, or cancels editing a note.
    showNote.delegate = self;
    // The detail view controller will share the same NSURLSession
    showNote.session = _session;
    

    if ([segue.identifier isEqualToString:@"editNote"]) {
        
        // pass selected note to be edited //
        if ([segue.identifier isEqualToString:@"editNote"]) {
            DBFile *note =  _notes[[self.tableView indexPathForSelectedRow].row];
            showNote.note = note;
        }
    }
}

#pragma mark - NoteDetailsViewController Delegate methods

-(void)noteDetailsViewControllerDoneWithDetails:(NoteDetailsViewController *)controller
{
    // refresh to get latest
    [self dismissViewControllerAnimated:YES completion:nil];
    [self notesOnDropbox];
}

-(void)noteDetailsViewControllerDidCancel:(NoteDetailsViewController *)controller
{
    // just close modal vc
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
