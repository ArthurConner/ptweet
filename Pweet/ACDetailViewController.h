//
//  ACDetailViewController.h
//  Pweet
//
//  Created by Arthur Conner on 8/8/14.
//  Copyright (c) 2014 Arthur Conner. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ACDetailViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) id detailItem;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@end
