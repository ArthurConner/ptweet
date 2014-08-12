//
//  ACOperationQueue.m
//  SquareOneMail
//
//  Created by Arthur Conner on 5/27/14.
//  Copyright (c) 2014 SquareOne Mail. All rights reserved.
//

#import "ACOperationQueue.h"

@class ACOperationLink;

#pragma mark - private

@interface ACOperation()

-(dispatch_block_t) _queueBlock;

@property (assign) CGFloat lockingTimeInterval;
@property (strong) dispatch_block_t mainQueblock;
@property (strong) dispatch_semaphore_t sema;
@property (strong) NSMutableArray *signalBlocks;
@property (strong) NSMutableArray *waitingOnBlocks;


@property (weak) ACOperationQueue *assumedQueue;

@end


@interface ACOperationQueue()

+(dispatch_queue_t)arrayQueue;

-(void)_runNonPending;
-(void)_signalCompletion:(ACOperation*)block;
-(void)_signalLink:(ACOperationLink *)link;

@property (assign) NSUInteger maxConcurrent;
@property (strong) dispatch_queue_t queue;
@property (strong) NSMutableArray *delegates;
@property (strong) NSMutableArray *pendingOperations;
@property (strong) NSMutableSet *activeOperations;

@end
#pragma mark - links

@interface ACOperationLink : NSObject
@property (weak) ACOperation *from;
@property (weak) ACOperation *to;
@property (strong) NSString *name;
@end

@implementation ACOperationLink

+(NSMutableSet *)allLinks{
    
    static dispatch_once_t onceToken;
    static NSMutableSet *theQueue;
    dispatch_once(&onceToken, ^{
        theQueue = [NSMutableSet set];
    });
    return theQueue;
}


-(void)dealloc{
    
   
   // NSLog(@"dealloc link \n\t|(%@)\n---",self.name);
  
}

-(NSString*)description{
    return  self.name;
}
@end

#pragma mark - operations

@implementation ACOperation
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.waitingOnBlocks = [NSMutableArray array];
        self.signalBlocks = [NSMutableArray array];
        self.lockingTimeInterval = 40;
       // self.cancel = NO;
    }
    return self;
}

-(void)dealloc{
    if (self.verbose){
        NSLog(@"dealloc operation \n\t|(%@)(%@)\n\t|took time %f secs \n\t|(%@)\n\t|---",self.name,self.assumedQueue.name,-[self.runDate timeIntervalSinceNow],self.lastblocking);
    }
}


#pragma mark configuration

+(void)safeSignal:(dispatch_semaphore_t) semaphore{
    if (semaphore){
        dispatch_semaphore_signal(semaphore);
    }
}

-(void)configureWithLock:(ACOperation_block_t)block{
    self.sema = dispatch_semaphore_create(0);
    
 
    
   __weak dispatch_semaphore_t inner = self.sema;

    

    self.mainQueblock = ^{block(inner);};

}

-(void)configureNoLock:(dispatch_block_t)block{
    self.mainQueblock = block;
    
}



-(void)addDependency:(ACOperation*)other{
    
    if (self.waitingOnBlocks==nil){
        NSLog(@"operaion (%@) is running. can't add depend %@",self.name,other.name);
    }
    
    dispatch_async([ACOperationQueue arrayQueue], ^{
        NSSet *knownDependencies = [other _upstreamDepends];
        
        if (!([knownDependencies member:self])){
            
            ACOperationLink *link = [[ACOperationLink alloc] init];
            link.from = other;
            link.to  = self;
            link.name = [NSString stringWithFormat:@"%@ --> %@",other.name,self.name];
            
            [self.waitingOnBlocks addObject:link];
            [other.signalBlocks addObject:link];
        }
    });
    
}

#pragma mark private

-(dispatch_block_t) _queueBlock{
    
    __weak ACOperation *inner = self;
    
    if (self.sema){
        return ^{
            
            if (inner.verbose){
                NSLog(@"operation (%@)(%@) starting with locks",inner.name,inner.assumedQueue.name);
            }
            
            inner.runDate = [NSDate date];
            
            dispatch_time_t semTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(inner.lockingTimeInterval * NSEC_PER_SEC));
            
            if (inner.mainQueblock){
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(),inner.mainQueblock);
                dispatch_semaphore_wait(inner.sema, semTime);
                
            } else{
                NSLog(@"%@%@ is behaving strangly",inner.name,inner.assumedQueue.name);
            }
            
            [inner _markFinished];
            
            
        };
        
    } else{
        
        return ^{
            
            if (inner.verbose){
                NSLog(@"operation (%@)(%@) starting without locks",inner.name,inner.assumedQueue.name);
            }
            
            inner.runDate = [NSDate date];
            
            if (inner.mainQueblock){
                inner.mainQueblock();
            }
            
            [inner _markFinished];
            if (inner.verbose){
                NSLog(@"operation (%@)(%@) finished without locks",inner.name,inner.assumedQueue.name);
            }
        };
    }
    
}

//needs to be on +(dispatch_queue_t)arrayQueue
-(NSMutableSet *)_upstreamDepends{
    //make sure we don't have a cycle
    NSMutableSet *checkingDepend = [NSMutableSet setWithObject:self];
    NSMutableSet *knownDepn = [NSMutableSet setWithObject:self];
    
    while (checkingDepend.count){
        NSArray *list = checkingDepend.allObjects;
        [checkingDepend removeAllObjects];
        
        for (ACOperation *op in list){
            
            for (ACOperationLink *link in op.waitingOnBlocks){
                ACOperation *nextOp = link.from;
                
                if (!([knownDepn member:nextOp])){
                    [checkingDepend addObject:nextOp];
                    [knownDepn addObject:nextOp];
                }
            }
        }
    }
    
    return knownDepn;
}


-(void)_markFinished{
    dispatch_async([ACOperationQueue arrayQueue], ^{
        NSMutableSet *set = [NSMutableSet set];
        
        for (ACOperationLink *op in self.signalBlocks){
        
            [op.to.assumedQueue _signalLink:op];
            if (op.to.assumedQueue){
            [set addObject:op.to.assumedQueue];
            }
        }
        [self.signalBlocks removeAllObjects];
        self.signalBlocks = nil;
        
        for (ACOperationQueue *queue in set){
            [queue _runNonPending];
        }
        
        [self.assumedQueue _signalCompletion:self];
    });
}


@end


@interface ACOperationQueueDelegateHolder : NSObject

@property (weak) NSObject<ACOperationQueueDelegate> *delegate;
@end

@implementation ACOperationQueueDelegateHolder

@end;


@implementation ACWaitOperation

-(void)configureWaitOnQueue:(ACOperationQueue *)queue{
    [queue addDelegate:self];
    self.sema = dispatch_semaphore_create(0);
    self.mainQueblock = ^{};
    
}

-(void)acQueueDidFinish:(ACOperationQueue *)queue{
    self.destQueue = queue;
    dispatch_semaphore_signal(self.sema);
}

@end



@implementation ACOperationQueue

+(dispatch_queue_t)arrayQueue{
    
    static dispatch_once_t onceToken;
    static dispatch_queue_t theQueue;
    dispatch_once(&onceToken, ^{
        theQueue = dispatch_queue_create("me.moments4.ACOperation.array", DISPATCH_QUEUE_SERIAL);
    });
    return theQueue;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.pendingOperations = [NSMutableArray array];
        self.activeOperations = [NSMutableSet set];
        self.verbose = NO;
        self.delegates = [NSMutableArray array];
    }
    return self;
}



+(instancetype)concurrentQueueWithName:(NSString *)name size:(NSUInteger)queueSize delegate:(NSObject<ACOperationQueueDelegate> *)delegate{
    
    ACOperationQueue *retQueue = [[self alloc] init];
    retQueue.name = name;
    [retQueue addDelegate:delegate];
    retQueue.maxConcurrent = queueSize;
    retQueue.queue = dispatch_queue_create([name UTF8String], DISPATCH_QUEUE_CONCURRENT);

    return retQueue;
}

+(instancetype)serialQueueWithName:(NSString *)name delegate:(NSObject<ACOperationQueueDelegate> *)delegate{
    
    ACOperationQueue *retQueue = [[self alloc] init];
    retQueue.name = name;
    [retQueue addDelegate:delegate];
    retQueue.maxConcurrent = 0;
    retQueue.queue = dispatch_queue_create([name UTF8String], DISPATCH_QUEUE_SERIAL);
  
    return retQueue;
}


-(void)addDelegate:(NSObject<ACOperationQueueDelegate> *)delegate{
    
    if (delegate){
        ACOperationQueueDelegateHolder *holder = [[ACOperationQueueDelegateHolder alloc] init];
        holder.delegate = delegate;
        [self.delegates addObject:holder];
    }
    
}
-(NSArray*)_blocksInOrder{
    return self.pendingOperations;
}

-(void)_runNonPending{
    
    dispatch_async([ACOperationQueue arrayQueue], ^{
        NSMutableArray *blocked = [NSMutableArray array];
        NSMutableArray *runArray = [NSMutableArray array];
        NSArray *orderedBlocks = [self _blocksInOrder];
        for (ACOperation *op in orderedBlocks){
            if (op.waitingOnBlocks.count == 0){
                [runArray addObject:op];
            } else {
                [blocked addObject:op];
            }
        }
        
        NSUInteger lockedCount = 0;
        for (ACOperation *op in runArray){
            if ((self.maxConcurrent==0)||(self.activeOperations.count < self.maxConcurrent)){
                
                if (!([self.activeOperations member:op])){
                [self.pendingOperations removeObject:op];
                [self.activeOperations addObject:op];
                op.waitingOnBlocks = nil;
                dispatch_async(self.queue,op._queueBlock);
                   
                   // op.mainQueblock = nil;
                   // op.preambleBlock=nil;
                } else {
                    NSLog(@"we are trying this twice");
                }
            } else if (self.maxConcurrent!=0) {
                lockedCount++;
            }
        }
        
        if (self.verbose){
            NSLog(@"%@ has %lu blocked operations with capactity %lu and free %lu pending %lu",self.name,(unsigned long)blocked.count,(unsigned long)self.maxConcurrent,(unsigned long)lockedCount,(unsigned long)self.pendingOperations.count);
            
            NSMutableArray *lines = [NSMutableArray array];
            for (ACOperation *op in self.activeOperations){
                [lines addObject:[NSString stringWithFormat:@"%@ %@ %@",self.name,op.runDate,op.name]];
            }
            [lines sortUsingSelector:@selector(compare:)];
            NSLog(@"%@ running\n\t\t%@",self.name,[lines componentsJoinedByString:@"\n\t\t"] );
                  
        }
    });
}


-(void)addPendingOperationsObject:(ACOperation *)object{
    dispatch_async([ACOperationQueue arrayQueue], ^{
        object.assumedQueue = self;
        object.verbose = self.verbose;
        [self.pendingOperations addObject:object];
        
        if (self.verbose){
          //  NSLog(@"%@ added to %@ withDepends size %lu",object.name,self.name,(unsigned long)object.waitingOnBlocks.count);
        }
        [self _runNonPending];
    });
    
}

-(void)addPriorityOperation:(ACOperation *)addBlock isHigh:(BOOL)isHigh{
    dispatch_async([ACOperationQueue arrayQueue], ^{
        for (ACOperation *op in self.pendingOperations) {
            
            if (op.queuePriority != addBlock.queuePriority){
                
                if (isHigh){
                    [op addDependency:addBlock];

                } else {
                    [addBlock addDependency:op];
                }
            } else {
               //These are equal
            }
        }
        
        addBlock.assumedQueue = self;
        addBlock.verbose = self.verbose;
        [self.pendingOperations addObject:addBlock];
        [self _runNonPending];
    });
}

-(void)_signalLink:(ACOperationLink *)link{
    if (link){
        ACOperation *toBlock = link.to;
        ACOperation *fromBlock = link.from;
        
        if (toBlock){
            [toBlock.waitingOnBlocks removeObject:link];
            
            if (toBlock.verbose){
                toBlock.lastblocking = [NSString stringWithFormat:@"blocked on %@(%@)",fromBlock.assumedQueue.name,fromBlock.name];
            }
            
            if (self.verbose){
                NSLog(@"signalLink:queue{%@} %@ (%@ remain)",self    ,link,toBlock.waitingOnBlocks);
                
                dispatch_async([ACOperationQueue arrayQueue], ^{
                    [self _debugPrint];
                });
                
            }
        }
    }
}


-(void)_debugPrint{
    NSMutableSet *priors = [NSMutableSet set];
    for (ACOperation *op in self.pendingOperations){
        NSMutableSet *opSet = [op _upstreamDepends];
        [opSet removeObject:op];
        
        [priors addObjectsFromArray:opSet.allObjects];
    }
    
    NSMutableDictionary *debugDict = [NSMutableDictionary dictionary];
    
    for (ACOperation *op in priors){
        NSString *key = op.assumedQueue.name;
        if (key==nil){
            key = @"unknown";
        }
        
        NSMutableArray *names = [debugDict objectForKey:key];
        if (names == nil){
            names = [NSMutableArray array];
            [debugDict setObject:names forKey:key];
        }
        [names addObject:[NSString stringWithFormat:@"%@",op.name]];
    }
    
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *queueName in debugDict.allKeys){
        NSArray *list = [debugDict objectForKey:queueName];
        if ([queueName compare:self.name]==NSOrderedSame){
             [lines addObject:[NSString stringWithFormat:@"queue(self) %@ has %lu",queueName,(unsigned long)list.count]];
        } else if ([queueName compare:self.name]==NSOrderedSame){
                 [lines addObject:[NSString stringWithFormat:@"queue %@ has %lu",queueName,(unsigned long)list.count]];
        } else {
             [lines addObject:[NSString stringWithFormat:@"queue %@ has %lu",queueName,(unsigned long)list.count]];
            
        }
    }
    
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSLog(@"\n\t%@",[lines componentsJoinedByString:@"\n\t"]);
    }];
    
}

-(void)_signalCompletion:(ACOperation*)block{
    dispatch_async([ACOperationQueue arrayQueue], ^{
        [self.activeOperations removeObject:block];
        
        if (self.activeOperations.count + self.pendingOperations.count==0){
            NSMutableArray *killArray = [NSMutableArray array];
            for (ACOperationQueueDelegateHolder *holder in self.delegates){
                if (holder.delegate && [holder.delegate respondsToSelector:@selector(acQueueDidFinish:)]){
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        [holder.delegate acQueueDidFinish:self];
                    }];
                    
                } else {
                    [killArray addObject:holder];
                }
            }
            for (NSObject *killMe in killArray){
                [self.delegates removeObject:killMe];
            }
        }
        
        
        
        if (self.verbose){
             NSLog(@"ACOperationqueue %@ emptied",self.name);
            [self _debugPrint];
        }
        [self _runNonPending];
    });
}


+(void)haultList:(NSArray*)array{
    NSLog(@"haultList: is not operational");
    return;
    
    
    dispatch_async([ACOperationQueue arrayQueue], ^{
        
        for (ACOperationQueue *queue in array){
        NSMutableArray *lines = [NSMutableArray array];
        
        for (ACOperation *op in queue.activeOperations){
            [lines addObject:[NSString stringWithFormat:@"active\t%@",op.name]];
            [op _markFinished];
        }
        [queue.activeOperations removeAllObjects];
        
        [lines addObject:[NSString stringWithFormat:@"pending\tcount:%lu",(unsigned long)queue.pendingOperations.count]];
        for (ACOperation *op in queue.pendingOperations){
            [op _markFinished];
        }
        [queue.pendingOperations removeAllObjects];
        
        NSMutableArray *killArray = [NSMutableArray array];
        for (ACOperationQueueDelegateHolder *holder in queue.delegates){
            if (holder.delegate && [holder.delegate respondsToSelector:@selector(acQueueDidFinish:)]){
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [holder.delegate acQueueDidFinish:queue];
                }];
                
            } else {
                [killArray addObject:holder];
            }
        }
        for (NSObject *killMe in killArray){
            [queue.delegates removeObject:killMe];
        }
        
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
           NSLog(@"*****\n\t\tQueue %@ halted\n*\t%@\n*****",queue.name,[lines componentsJoinedByString:@"\n*\t]"]);
        }];
            
        }
       
    });
}

@end

@implementation ACUrlOperationStack

-(NSArray*)_blocksInOrder{
    return [[self.pendingOperations  reverseObjectEnumerator] allObjects];
}

-(void)dowloadUrlStr:(NSString *)urlStr{

    __weak NSObject<ACUrlOperationStackDelegate> *innerDelgate = self.urlDelegate;
    __weak  ACUrlOperationStack *inner = self;
    
    ACOperation *op = [[ACOperation alloc] init];
    
    [op configureWithLock:^(dispatch_semaphore_t a){
         NSURL *url = [NSURL URLWithString:urlStr];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        if (request){
            
            [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse* response, NSData* data, NSError* connectionError){
            
                [innerDelgate acURLOperationStack:inner didDownloadFrom:urlStr data:data error:connectionError];
                 [ACOperation safeSignal:a];
            }];
            
            
        } else {
            [ACOperation safeSignal:a];
        }
        
    }];
    
    [self addPendingOperationsObject:op];
    
    
}



@end

