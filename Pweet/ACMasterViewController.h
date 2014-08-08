//
//  ACMasterViewController.h
//  Pweet
//
//  Created by Arthur Conner on 8/8/14.
//  Copyright (c) 2014 Arthur Conner. All rights reserved.
//

#import <UIKit/UIKit.h>

@class ACDetailViewController;

#import <CoreData/CoreData.h>

@interface ACMasterViewController : UITableViewController <NSFetchedResultsControllerDelegate>

@property (strong, nonatomic) ACDetailViewController *detailViewController;

@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end
