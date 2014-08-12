//
//  ACDetailViewController.h
//  Pweet
//
//  Created by Arthur Conner on 8/8/14.
//  Copyright (c) 2014 Arthur Conner. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ACDetailViewController : UIViewController <UISplitViewControllerDelegate>

@property (strong, nonatomic) NSManagedObject *detailItem;

@property (strong)  UILabel *tweetLabel;
@property (strong)  UIImageView *imageView;
@property (assign) BOOL didAddConstraints;
@end
