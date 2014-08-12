//
//  ACTwitterFacade.m
//  Pweet
//
//  Created by Arthur Conner on 8/8/14.
//  Copyright (c) 2014 Arthur Conner. All rights reserved.
//

#import "ACTwitterFacade.h"

#import <Social/Social.h>
#import <Accounts/Accounts.h>
#import "ACLogger.h"


@interface ACTwitterFacade()
//Private
@property (strong)  ACAccountStore *accountStore;


@property ( strong, nonatomic) NSManagedObjectContext *backgroundManagedObjectContext;
@property (strong) NSNumber *lastNum;

@property (strong) NSCache *imageCache;
@property (strong) NSMutableSet *pendingDownloads;
@property (strong) ACUrlOperationStack *imageStack;
@property (strong) ACOperationQueue *twitterRequestQueue;
@end

@implementation ACTwitterFacade

+(instancetype)sharedFacade{
    static ACTwitterFacade *retFacade;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        retFacade = [[ACTwitterFacade alloc] init];
        retFacade.imageCache = [[NSCache alloc] init];
        [retFacade.imageCache setCountLimit:30];
        retFacade.pendingDownloads = [NSMutableSet set];
        retFacade.imageStack = [ACUrlOperationStack concurrentQueueWithName:@"twitterImages" size:5 delegate:nil];
        retFacade.imageStack.urlDelegate = retFacade;
        
        retFacade.twitterRequestQueue = [ACOperationQueue serialQueueWithName:@"twitterRequests" delegate:nil];
        //retFacade.imageStack.verbose = YES;
        
    });
    return retFacade;
}

#pragma mark - core data interaction

-(void)_loadTweetArray:(NSArray *)tweetList{
    
    NSString *entityName = @"Tweet";
    NSString *primaryKey = @"idint";
    
    if (self.backgroundManagedObjectContext==nil){
        self.backgroundManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        self.backgroundManagedObjectContext.parentContext = self.uiManagedObjectContext;
    }
    
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:self.uiManagedObjectContext];
    
    
    [self.backgroundManagedObjectContext performBlock:^{
        
        
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName: entityName];
        [request setPropertiesToFetch:@[primaryKey]];
        
        NSError *error = nil;
        
        NSArray *results = [self.uiManagedObjectContext executeFetchRequest:request error:&error];
        
        if (error){
            [self _handleError:error];
            return ;
        }
        
        //We probably should not load the entire set of tweets into memory but instead pick only the ones that are in the range
        //from the highest and lowest return values.
        NSMutableSet *alreadyInSystem = [NSMutableSet set];
        for (NSManagedObject *obj in results){
            [alreadyInSystem addObject:[obj valueForKey:primaryKey]];
        }
        
        for (NSDictionary *dict in tweetList){
            
            NSObject *pKey = [dict objectForKey:primaryKey];
            if (![alreadyInSystem member:pKey]){
                [alreadyInSystem addObject:pKey];
                
                NSManagedObject *tweet = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:self.backgroundManagedObjectContext];
                
                for (NSString *key in dict){
                    [tweet setValue:[dict objectForKey:key] forKey:key];
                }
            } else {
                //  NSLog(@"Already have %@",pKey);
            }
            
            
        }
        
        
        if (![self.backgroundManagedObjectContext save:&error]) {
            [self _handleError:error];
        } else {
            
            [self.uiManagedObjectContext performBlock:^{
                NSError *error;
                if (![self.uiManagedObjectContext save:&error]){
                    [self _handleError:error];
                }
            }];
        }
        
    }];
    
}

-(void)_addDict:(NSObject *)item toAddList:(NSMutableArray *)add{
    if ([item respondsToSelector:@selector(objectForKey:) ]){
        NSDictionary *tweet = (NSDictionary *)item;
        
        NSObject *u = [tweet objectForKey:@"user"];
        if (u && [u respondsToSelector:@selector(objectForKey:)]){
            NSDictionary *user = (NSDictionary *)u;
            NSString *text = [tweet objectForKey:@"text"];
            NSNumber *idint = [tweet objectForKey:@"id"];
            
            NSString *name = [user objectForKey:@"name"];
            NSString *url = [user objectForKey:@"profile_image_url_https"];
            
            if (text && name && url && idint){
                [add addObject:@{@"text":text,@"name":name,@"url":url,@"idint":idint}];
            }
        }
        
    }
}
-(void)_handleData:(NSData *)data{
    
    if (data==nil){
        NSError *nilData = [NSError errorWithDomain:@"ACTweet" code:4 userInfo:@{}];
        [self _handleError:nilData];
        return;
    }
    
    NSError *e;
    
    NSObject *ret = [NSJSONSerialization  JSONObjectWithData: data options: NSJSONReadingMutableContainers error: &e];
    
    if (e){
        [self _handleError:e];
        return;
    }
    
    //Json serialization returns an id, so we need to make sure that it is an dictionary
    if ([ret respondsToSelector:@selector(objectForKey:)]){
        
        NSObject *lObject = [(NSDictionary *)ret objectForKey:@"statuses"];
        if ( lObject && [lObject respondsToSelector:@selector(objectAtIndex:)]){
            NSArray *list = (NSArray *)lObject;
            NSMutableArray *add = [NSMutableArray array];
            for (NSObject *item in list){
                [self _addDict:item toAddList:add];
                
                //  NSLog(@"%@",item);
            }
            
            if (add.count){
                [self _loadTweetArray:add];
            } else {
                NSLog(@"No Results");
            }
        } else {
            NSError *nilData = [NSError errorWithDomain:[NSString stringWithFormat:@"ACTweet-nolist:%@",ret] code:5 userInfo:@{}];
            [self _handleError:nilData];
        }
        
    } else {
        NSError *nilData = [NSError errorWithDomain:[NSString stringWithFormat:@"ACTweet:%@",ret] code:5 userInfo:@{}];
        [self _handleError:nilData];
        return;
    }
    
}

-(void)_handleError:(NSError *)error{
    
    [ACLogger logError:[error description] module:@"ACTwitterFacade"];
    
}

#pragma mark - Account store interaction

-(void)_getTweetsWithDictionary:(NSDictionary *)tweetProps completion:(void (^)())completion{
    
    NSLog(@"tweetProps: %@",tweetProps);
    
    if (self.accountStore==nil){
        self.accountStore = [[ACAccountStore alloc] init];
    }
    
  
    
    ACAccountType *accountTypeTw = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    [self.accountStore requestAccessToAccountsWithType:accountTypeTw options:NULL completion:^(BOOL granted, NSError *error) {
        
        
        if(granted) {
            
            
            
            NSArray *accountsArray = [self.accountStore accountsWithAccountType:accountTypeTw];
            
            if (accountsArray.count){
                ACAccount *tw_account = accountsArray[0];
                
                NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithObject:@"@peek" forKey:@"q"];
                
                if (tweetProps){
                    [parameters addEntriesFromDictionary:tweetProps];
                }
                
                
                
                SLRequest* twitterRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                                               requestMethod:SLRequestMethodGET
                                                                         URL:[NSURL URLWithString:@"https://api.twitter.com/1.1/search/tweets.json"]
                                                                  parameters:parameters];
                
                [twitterRequest setAccount:tw_account];
                
                [twitterRequest performRequestWithHandler:^(NSData* responseData, NSHTTPURLResponse* urlResponse, NSError* error) {
                    
                    
                    if (error){
                        [self _handleError:error];
                        if (completion){
                            completion();
                        }
                    } else {
                        
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        [self _handleData:responseData];
                            if (completion){
                                completion();
                            }
                        }];
                        
                    }

                    
                    
                }];
                
            }else {
                [self _handleError:[NSError errorWithDomain:@"no accounts" code:5 userInfo:nil]];
                if (completion){
                    completion();
                }
            }
            
            
        } else {
            
            //    NSNumber *errorCode = [errorDictionary valueForKey:@"code"];
            
            [self _handleError:[NSError errorWithDomain:@"nothing granted" code:6 userInfo:nil]];
            if (completion){
                completion();
            }
            
            //    NSArray *accountsArray = [accountStoreTw accountsWithAccountType:accountTypeTw];
            
        }

    }];
}



//this is very similar to the get tweets. We could try to come up with an abstract class.
-(void)retweet:(NSNumber *)number completion:(void (^)())completion{
    
    if (number==nil) return;
    
    NSString *urlstr = [NSString stringWithFormat:@"https://api.twitter.com/1.1/statuses/retweet/%@.json",number];
    
    
    if (self.accountStore==nil){
        self.accountStore = [[ACAccountStore alloc] init];
    }

    ACAccountType *accountTypeTw = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    [self.accountStore requestAccessToAccountsWithType:accountTypeTw options:NULL completion:^(BOOL granted, NSError *error) {

        if(granted) {
            
            NSArray *accountsArray = [self.accountStore accountsWithAccountType:accountTypeTw];
            if (accountsArray.count){
                ACAccount *tw_account = accountsArray[0];
                SLRequest* twitterRequest = [SLRequest requestForServiceType:SLServiceTypeTwitter
                                                               requestMethod:SLRequestMethodPOST
                                                                         URL:[NSURL URLWithString:urlstr]
                                                                  parameters:nil];
                
                [twitterRequest setAccount:tw_account];
                [twitterRequest performRequestWithHandler:^(NSData* responseData, NSHTTPURLResponse* urlResponse, NSError* error) {

                    if (error){
                        [self _handleError:error];
                        if (completion){
                            completion();
                        }
                    } else {
                        
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                            if (responseData==nil){
                                NSError *nilData = [NSError errorWithDomain:@"ACTweet" code:4 userInfo:@{}];
                                [self _handleError:nilData];
                                if (completion){
                                    completion();
                                }
                                return;
                            }
                            
                            NSError *e;
                            NSObject *item = [NSJSONSerialization  JSONObjectWithData: responseData options: NSJSONReadingMutableContainers error: &e];
                            
                            if (e){
                                [self _handleError:e];
                                if (completion){
                                    completion();
                                }
                                return;
                            }
                            
                            //Json serialization returns an id, so we need to make sure that it is an dictionary
                            if ([item respondsToSelector:@selector(objectForKey:)]){
                                NSMutableArray *add = [NSMutableArray array];
                                [self _addDict:item toAddList:add];
                                if (add.count){
                                    [self _loadTweetArray:add];
                                } else {
                                    NSLog(@"No Results");
                                }
                                
                                
                            } else {
                                NSError *nilData = [NSError errorWithDomain:[NSString stringWithFormat:@"ACTweet:%@",item] code:5 userInfo:@{}];
                                [self _handleError:nilData];
                                
                            }
                            if (completion){
                                completion();
                            }
                        }];  
                    }
                    
                }];
                
            }else {
                [self _handleError:[NSError errorWithDomain:@"no accounts" code:5 userInfo:nil]];
                if (completion){
                    completion();
                }
            }
            
            
        } else {
            
            //    NSNumber *errorCode = [errorDictionary valueForKey:@"code"];
            
            [self _handleError:[NSError errorWithDomain:@"nothing granted" code:6 userInfo:nil]];
            if (completion){
                completion();
            }
            
            //    NSArray *accountsArray = [accountStoreTw accountsWithAccountType:accountTypeTw];
            
        }
        
    }];
}

-(void)getTweets{
    
    //just to make sure we are on the right queue
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        
        NSDictionary *parameters = nil;
        
        
        NSString  *idint = @"idint";
        
        //search above the newest tweet
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Tweet"];
        
        fetchRequest.fetchLimit = 1;
        fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:idint ascending:NO]];
        fetchRequest.propertiesToFetch   = @[idint];
        
        NSError *error = nil;
        
        NSManagedObject *tweet = [self.uiManagedObjectContext executeFetchRequest:fetchRequest error:&error].lastObject;
        NSNumber *checkNumber = [tweet valueForKey:idint];
        
        
        if (checkNumber) {
            parameters = @{@"min_id": [checkNumber description] };
        } //otherwise since we don't have any tweets search above.
        
        ACOperation *op = [[ACOperation alloc] init];
        [op configureWithLock:^(dispatch_semaphore_t a){
            [self _getTweetsWithDictionary:parameters completion:^{
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"TweetDidRefesh" object:nil];
                    [ACOperation safeSignal:a];
                }];
            }];
        }];
        
        [self.twitterRequestQueue addPendingOperationsObject:op];
        
    }];
    
    
}

-(void)getOlderTweets{

    //just to make sure we are on the right queue
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        ACOperation  *op= nil;
        NSString  *idint = @"idint";
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Tweet"];
        
        fetchRequest.fetchLimit = 1;
        //search below smallest id
        fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:idint ascending:YES]];
        fetchRequest.propertiesToFetch   = @[idint];
        
        NSError *error = nil;
        
        NSManagedObject *tweet = [self.uiManagedObjectContext executeFetchRequest:fetchRequest error:&error].lastObject;
        NSNumber *checkNumber = [tweet valueForKey:idint];
        
        
        if (checkNumber) {
            
            if (self.lastNum==nil){
                
                self.lastNum = checkNumber;
                
                op = [[ACOperation alloc] init];
                [op configureWithLock:^(dispatch_semaphore_t a){
                    [self _getTweetsWithDictionary:@{@"max_id": [checkNumber description] } completion:^{
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                            self.lastNum = nil;
                            [ACOperation safeSignal:a];
                        }];
                    }];
                }];
                
                
            } else {
                //  NSLog(@"we are looking at %@ versus %@",self.lastNum,idstr);
            }
        }
        
        
        if (op){
            [self.twitterRequestQueue addPendingOperationsObject:op];
        }
        
    }];
    
    
    
}

#pragma mark - image handling

-(UIImage *)imageAtURL:(NSString*)urlStr{
    
    if (urlStr==nil) return nil;
    
    UIImage *retImage =  [self.imageCache objectForKey:urlStr];
    
    if (retImage == nil){
        
        if (!([self.pendingDownloads member:urlStr])){
            [self.pendingDownloads addObject:urlStr ];
            [self.imageStack dowloadUrlStr:urlStr];
        }
    }
    
    return retImage;
    
    
}


-(void)acURLOperationStack:(ACUrlOperationStack *)stack didDownloadFrom:(NSString *)urlStr data:(NSData *)data error:(NSError *)error{
    
    [self.pendingDownloads removeObject:urlStr];
    
    if (error){
        [self _handleError:error];
    } else {
        if (data){
            UIImage *image = [UIImage imageWithData:data];
            if (image) {
                
                //  NSLog(@"Got image %@",urlStr);
                
                [self.imageCache setObject:image forKey:urlStr];
                
                NSString *entityName = @"Tweet";
                NSString *updateField = @"imageupdate";
                
                [self.uiManagedObjectContext performBlock:^{
                    
                    NSError *error;
                    
                    
                    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName: entityName];
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"url=%@",urlStr];
                    [request setPredicate:predicate];
                    
                    NSArray *results = [self.uiManagedObjectContext executeFetchRequest:request error:&error];
                    
                    if (error){
                        [self _handleError:error];
                        return ;
                    }
                    
                    NSString *filepathTime = [[NSDate date]description];
                    for (NSManagedObject *obj in results){
                        [obj setValue:filepathTime forKey:updateField   ];
                    }
                    
                    if (![self.uiManagedObjectContext save:&error]) {
                        [self _handleError:error];
                    }
                    
                }];
            }
        }
    }
    
}

@end
