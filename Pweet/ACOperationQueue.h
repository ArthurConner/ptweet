//
//  ACOperationQueue.h
//  SquareOneMail
//
//  Created by Arthur Conner on 5/27/14.
//  Copyright (c) 2014 SquareOne Mail. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ACOperationQueue;
typedef void (^ACOperation_block_t)(dispatch_semaphore_t a);

@protocol ACOperationQueueDelegate <NSObject>
-(void)acQueueDidFinish:(ACOperationQueue *)queue;
@end


#pragma mark - Operation
@interface ACOperation : NSObject

-(void)addDependency:(ACOperation*)other;
-(void)configureNoLock:(dispatch_block_t)block;
-(void)configureWithLock:(ACOperation_block_t)block;

+(void)safeSignal:(dispatch_semaphore_t) semaphore;


@property (assign) BOOL verbose;
@property (assign) NSInteger queuePriority;
@property (strong) NSDate *runDate;
@property (strong) NSString *lastblocking;
@property (strong) NSString *name;

@end


@interface ACWaitOperation : ACOperation<ACOperationQueueDelegate>
-(void)configureWaitOnQueue:(ACOperationQueue *)queue;
@property(weak)ACOperationQueue *destQueue;
@end

#pragma mark - queue

@interface ACOperationQueue : NSObject

+(instancetype)concurrentQueueWithName:(NSString *)name size:(NSUInteger)queueSize delegate:(NSObject<ACOperationQueueDelegate> *)delegate;;
+(instancetype)serialQueueWithName:(NSString *)name delegate:(NSObject<ACOperationQueueDelegate> *)delegate;
+(void)haultList:(NSArray*)array;

-(void)addDelegate:(NSObject<ACOperationQueueDelegate> *)delegate;
-(void)addPendingOperationsObject:(ACOperation *)object;
-(void)addPriorityOperation:(ACOperation *)object isHigh:(BOOL)isHigh;

@property (assign) BOOL verbose;
@property (strong) NSString *name;

@end

@class ACUrlOperationStack;

@protocol ACUrlOperationStackDelegate <NSObject>
-(void)acURLOperationStack:(ACUrlOperationStack *)stack didDownloadFrom:(NSString*)urlStr data:(NSData*)data error:(NSError*)error;
@end

@interface ACUrlOperationStack :ACOperationQueue;
@property (weak) NSObject<ACUrlOperationStackDelegate> *urlDelegate;
-(void) dowloadUrlStr:(NSString *)urlStr;
@end

