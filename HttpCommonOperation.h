//
//  HttpCommonOperation.h
//  NetRecord_BJ
//
//  Created by adt on 13-12-5.
//  Copyright (c) 2013年 MasterCom. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^ResponseHandler)(NSDictionary *);
typedef void (^ResponseNSDataHandler)(NSData *);
@interface HttpCommonOperation : NSOperation <NSURLConnectionDelegate, NSURLConnectionDataDelegate> {
	NSString *_url;
	NSDictionary *_params;
}

- (id)initWithURL:(NSString *)url params:(NSDictionary *)params;
- (id)initWithURL:(NSString *)url params:(NSDictionary *)params isDataZip:(BOOL)isZip;
- (id)initMTDataZipWithURL:(NSString *)url params:(NSDictionary *)params;
- (id)initNoZipWithURL:(NSString *)url params:(NSDictionary *)params;
- (id)initWithURL:(NSString *)url params:(NSDictionary *)params  isDataImage:(BOOL)isImage;
- (void)setResponseHandler:(ResponseHandler)handler;
- (void)setResponseNSDataHandler:(ResponseNSDataHandler)handler;
- (void)setTimeout:(NSInteger) timeout;
@end
