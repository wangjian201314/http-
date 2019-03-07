//
//  HttpCommon.h
//  MTNOP
//
//  Created by renwanqian on 14-4-16.
//  Copyright (c) 2014年 cn.mastercom. All rights reserved.
//


#import <Foundation/Foundation.h>
#import "MTOfflineManager.h"



#define MTRequestTimeOut 90


@class AFHTTPRequestOperation;
typedef void (^MessageHandler)(NSDictionary * response);
typedef void (^MessageNSDataHandler)(NSData * data);
typedef void (^ErrorHandler)(NSDictionary * error);
typedef void (^MessageTimeOutHandler)(NSDictionary * response);

typedef void (^AFHTTPRequestOp)(AFHTTPRequestOperation *operation);
typedef void (^HandleProgress)(CGFloat progress);


@interface HttpCommon : NSObject {
	NSOperationQueue *_opreationQueue;
}

//=============================================================
/** 重登录中 */
@property (nonatomic) BOOL isRelogining;
/** Cookies */
@property (strong, nonatomic) NSMutableArray * cookies;
/** lastSessionCookie */
@property (strong, nonatomic) NSHTTPCookie * lastSession;
//=============================================================

@property (nonatomic, strong) NSDictionary *urlAndParams;

@property (nonatomic, strong) NSString *serverAddress;

@property (nonatomic, assign) NSInteger maxConcurrentOperationCount;

@property (nonatomic, assign) NSInteger timeout;

+ (instancetype)sharedInstance;
+ (instancetype)sharedInstanceWithURL:(NSString *)url;

+(NSString*) serverAdress;
+(NSString*) serverAdressWithNoPort;
- (void)cancelAllOperations;


#pragma mark -
#pragma mark - 全自定义簇方法

/**
 *  全自定义请求字段说明
 *
 *  **必填项**
 *
 *  @param uri     : 资源路径(请求字段)
 *  @param params  : 请求参数
 *  @param handler : 数据处理
 *
 *  --选填项--
 *
 *  @param loadingHint      提示内容
 *
 *  @param doneHint         完成提示
 *
 *  @param isZip            是否是 zip 加密, 默认是 MTZIP
 *
 *  @param timeOutHandler   超时回调, 如果不为空, 超时之后框架会自动重连一次
 *
 *  @param customSuccess    是否自定义处理数据 (框架不做任何逻辑处理,只返回原始数据)
 *
 *  @param isImage          表示返回的数据格式是图片原始数据(原意:这个参数其实就是判断是否是NSData)
 */

#pragma mark - MTZip加密(默认)


/**
 *  无提示
 */
- (void)requestNoHintWithURL:(NSString *)uri Params:(NSDictionary *)params Handler:(MessageHandler)handler;


/**
 *  默认提示 "正在加载..."
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params Handler:(MessageHandler)handler;


/**
 *  自定义提示
 *
 *  @param loadingHint 提示内容
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint Handler:(MessageHandler)handler;


/**
 *  自定义加载提示和自定义处理过程
 *
 *  @param loadingHint      提示内容
 *
 *  @param customSuccess    是否自定义处理数据 (框架不做任何逻辑处理,只返回原始数据)
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint customSuccess:(BOOL)customSuccess Handler:(MessageHandler)handler;


/**
 *  自定义加载和完成提示
 *
 *  @param loadingHint  提示内容
 *
 *  @param doneHint     完成提示
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler;


/**
 *  自定义加载提示 -超时重连
 *
 *  @param loadingHint      提示内容
 *
 *  @param timeOutHandler   超时回调, 如果不为空, 超时之后框架会自动重连一次
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint Handler:(MessageHandler)handler timeOutHandler:(MessageTimeOutHandler)timeOutHandler;


/**
 *  自定义加载和完成提示 -超时重连
 *
 *  @param loadingHint      提示内容
 *
 *  @param doneHint         完成提示
 *
 *  @param timeOutHandler   超时回调, 如果不为空, 超时之后框架会自动重连一次
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler timeOutHandler:(MessageTimeOutHandler)timeOutHandler;


#pragma mark 方法名 requestMTZipWithURL 开头
//  以下三个方法与上述方法重复, 将要舍弃, 不建议使用
/**
 *  自定义提示
 *
 *  @param loadingHint 提示内容
 */
- (void)requestMTZipWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint Handler:(MessageHandler)handler NS_DEPRECATED_IOS(2_0, 8_0);


/**
 *  自定义提示 -命名不规范, 将要舍弃
 *
 *  @param loadingHint 提示内容
 */
- (void)requestMTGzipWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint Handler:(MessageHandler)handler NS_DEPRECATED_IOS(2_0, 7_0);


/**
 *  自定义加载和完成提示
 *
 *  @param loadingHint  提示内容
 *
 *  @param doneHint     完成提示
 */
- (void)requestMTZipWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler NS_DEPRECATED_IOS(2_0, 8_0);


#pragma mark - Zip加密


/**
 *  无任何提示 默认 isZip=YES
 */
- (void)requestGzipWithURL:(NSString *)uri Params:(NSDictionary *)params Handler:(MessageHandler)handler;


/**
 *  自定义加载和完成提示 -gzip
 *
 *  @param loadingHint  提示内容
 *
 *  @param doneHint     完成提示
 *
 *  @param isZip            是否是 zip 加密, 默认是 MTZIP
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler isZip:(BOOL)isZip;


/**
 *  自定义加载和完成提示 -gzip
 *
 *  @param loadingHint      提示内容
 *
 *  @param doneHint         完成提示
 *
 *  @param isZip            是否是 zip 加密, 默认是 MTZIP
 *
 *  @param customSuccess    是否自定义处理数据 (框架不做任何逻辑处理,只返回原始数据)
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler  isZip:(BOOL)isZip customSuccess:(BOOL)customSuccess;

/**
 *  自定义加载和完成提示 -gzip -超时重连
 *
 *  @param loadingHint      提示内容
 *
 *  @param doneHint         完成提示
 *
 *  @param isZip            是否是 zip 加密, 默认是 MTZIP
 *
 *  @param timeOutHandler   超时回调, 如果不为空, 超时之后框架会自动重连一次
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler timeOutHandler:(MessageTimeOutHandler)timeOutHandler isZip:(BOOL)isZip;





/**
 Zip加密
 */
//- (void)requestGzipWithURL:(NSString *)uri Params:(NSDictionary *)params Handler:(MessageHandler)handler;
//- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler isZip:(BOOL)isZip;

//- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler isZip:(BOOL)isZip customSuccess:(BOOL)customSuccess;
//- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler timeOutHandler:(MessageTimeOutHandler)timeOutHandler isZip:(BOOL)isZip customSuccess:(BOOL)customSuccess;

/**
 MtZip加密
 */
//- (void)requestNoHintWithURL:(NSString *)uri Params:(NSDictionary *)params Handler:(MessageHandler)handler;

//- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params Handler:(MessageHandler)handler;
//- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint Handler:(MessageHandler)handler;
//- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler;

//- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint customSuccess:(BOOL)customSuccess Handler:(MessageHandler)handler;

//- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint Handler:(MessageHandler)handler timeOutHandler:(MessageTimeOutHandler)timeOutHandler;
//- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler timeOutHandler:(MessageTimeOutHandler)timeOutHandler;

//- (void) requestMTGzipWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint Handler:(MessageHandler)handler ;

#pragma mark - 未重写部分
/*
 没有Zip加密 - by Chencanfeng
 */

- (void)requestNoZipWithURL:(NSString *)uri Params:(NSDictionary *)params Handler:(MessageHandler)handler;
- (void)requestNoZipWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint Handler:(MessageHandler)handler;
- (void)requestNoZipWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler;
- (void)requestNoZipWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint customSuccess:(BOOL)customSuccess Handler:(MessageHandler)handler;

/*
 上传文件
 */
- (void)uploadWithURL:(NSString *)uri Params:(NSDictionary *)params FileURLs:(NSArray *)fileURLs Handler:(MessageHandler)handler;

/*
 上传文件, 带上传进度
 */
- (void)uploadWithURL:(NSString *)uri Params:(NSDictionary *)params FileURLs:(NSArray *)fileURLs Operation:(AFHTTPRequestOp)op Progress:(HandleProgress)progress Handler:(MessageHandler)handler;


/**
 *  isImage这个参数其实就是判断是否是nsdata
 *
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageNSDataHandler)handler isImage:(BOOL)isImage;

#pragma mark - 同步请求

- (NSDictionary *)respondSyncFromURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint;

- (NSData *) respondSyncDataFromURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint;

- (NSData*)syncGetRequestWithURL:(NSString*)uri params:(NSDictionary*)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint;
@end
