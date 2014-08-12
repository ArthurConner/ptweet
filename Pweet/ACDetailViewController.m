//
//  ACDetailViewController.m
//  Pweet
//
//  Created by Arthur Conner on 8/8/14.
//  Copyright (c) 2014 Arthur Conner. All rights reserved.
//

#import "ACDetailViewController.h"
#import "ACTwitterFacade.h"

@interface ACDetailViewController ()
@property (strong, nonatomic) UIPopoverController *masterPopoverController;
- (void)configureView;
@end

@implementation ACDetailViewController

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem
{
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
        
        // Update the view.
         self.didAddConstraints = NO;
        [self configureView];
    }

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }        
}

- (void)configureView
{

    if (self.tweetLabel == nil){
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0,0,10,10)];
        label.numberOfLines = 0;
        self.tweetLabel = label;
    }
    
    if (self.detailItem) {
        self.tweetLabel.text = [self.detailItem valueForKey:@"text"];
        
        NSLog(@"%@",self.tweetLabel.text);
    }
    
  
    ACTwitterFacade *facade = [ACTwitterFacade sharedFacade];
    UIImage *image = [facade imageAtURL:[self.detailItem valueForKey:@"url"]];
     
    if (self.imageView==nil){
        if (image){
        UIImageView *iView = [[UIImageView alloc] initWithImage:image];
          self.imageView  = iView;
        } else{
        UIImageView *iView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        self.imageView  = iView;
            self.imageView.backgroundColor = [UIColor redColor];
    }
    }
    
    if (image){
        self.imageView.image = image;
        
    }


    //we need the self.didAddContstraints otherwise when we access the view for the first time
    //we go back into this section of code.
    if (!(self.didAddConstraints)){
        self.didAddConstraints = YES;
        
        [self.view addSubview:self.tweetLabel];
        [self.view addSubview:self.imageView];
        
        //AutoLayout
        
        [self.imageView setTranslatesAutoresizingMaskIntoConstraints:NO];
        [self.tweetLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
   
        
        
        NSDictionary *viewsDictionary = @{@"imageView":self.imageView,@"detail":self.tweetLabel};
        NSArray *constraint_POS_V = [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-80-[imageView(==40)]-[detail(>=20)]-|"
                                                                            options:0
                                                                            metrics:nil
                                                                              views:viewsDictionary];
        
        NSArray *constraint_POS_H = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|-[detail(>=20)]-|"
                                                                            options:0
                                                                            metrics:nil
                                                                              views:viewsDictionary];
        [self.view addConstraints:constraint_POS_V];
        [self.view addConstraints:constraint_POS_H];
        
        NSLayoutAttribute placement = NSLayoutAttributeCenterX;
        NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:self.imageView
                                                                     attribute:placement
                                                                     relatedBy:NSLayoutRelationEqual
                                                                        toItem:self.view
                                                                     attribute:placement
                                                                    multiplier:1
                                                                      constant:0];
        [self.view addConstraint:constraint];
        

       
        
        
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self configureView];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Retweet" style:UIBarButtonItemStyleBordered target:self action:@selector(reTweet:)];
}


-(void)reTweet:(id)whatever{
    ACTwitterFacade *facade = [ACTwitterFacade sharedFacade];
    [facade retweet:[self.detailItem valueForKey:@"idint"] completion:^{
        NSLog(@"we retweeted");
    }];
    self.navigationItem.rightBarButtonItem = nil;
    
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
    barButtonItem.title = NSLocalizedString(@"Tweets", @"Tweets");
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}

@end
