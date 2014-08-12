//
//  ACLogger.m
//  Pweet
//
//  Created by Arthur Conner on 8/8/14.
//  Copyright (c) 2014 Arthur Conner. All rights reserved.
//

#import "ACLogger.h"

@implementation ACLogger

+(void)logError:(NSString *)description module:(NSString*)moduleName{
    NSLog(@"Error in %@ [%@]",moduleName,description);
}
@end
