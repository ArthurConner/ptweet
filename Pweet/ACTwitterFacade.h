//
//  ACTwitterFacade.h
//  Pweet
//
//  Created by Arthur Conner on 8/8/14.
//  Copyright (c) 2014 Arthur Conner. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "ACOperationQueue.h"

@class  ACAccountStore;

@interface ACTwitterFacade : NSObject<ACUrlOperationStackDelegate>

+(instancetype)sharedFacade;

-(void)getTweets;
-(void)getOlderTweets;
-(void)retweet:(NSNumber *)number completion:(void (^)())completion;


-(UIImage *)imageAtURL:(NSString*)urlStr;

@property ( strong, nonatomic) NSManagedObjectContext *uiManagedObjectContext;



@end
