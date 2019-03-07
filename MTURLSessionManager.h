//
//  MTURLSessionManager.h
//  UICommon
//
//  Created by xiuyuan on 2018/9/1.
//  Copyright © 2018年 YN. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MTURLSessionManager : NSObject
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler;
@end
