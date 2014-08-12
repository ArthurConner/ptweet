//
//  ACLogger.h
//  Pweet
//
//  Created by Arthur Conner on 8/8/14.
//  Copyright (c) 2014 Arthur Conner. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ACLogger : NSObject


+(void)logError:(NSString *)description module:(NSString*)moduleName;

@end
