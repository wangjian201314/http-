//
//  MTOfflineManager.h
//  UICommon
//
//  Created by kingste on 16/9/5.
//  Copyright © 2016年 YN. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MTOfflineManager : NSObject

+ (MTOfflineManager *)shareManager;



/** 登录是否为"离线模式" */
@property (nonatomic) BOOL isActive;
/** 版本是否支持离线模式(info文件内配置) */
@property (nonatomic) BOOL isAllowOffline;
/** 用户ID */
@property (nonatomic, copy)NSString * userID;
/** 用户名 */
@property (nonatomic, copy)NSString * username;
/** 当前模块 */
@property (nonatomic, copy)NSString * currentFunc;
/** 当前支持的模块 */
@property (nonatomic, strong)NSArray * supportFuncs;


/**
 *  更新"登录信息"
 */
- (BOOL)updateOfflineUserInfoUsername:(NSString*)username password:(NSString*)passward andResponse:(NSDictionary*)response;

/**
 *  记录回调(存)
 */
- (void)saveResponse:(NSDictionary*)response withUrl:(NSString*)url andParam:(NSDictionary*)param;



/**
 *  验证"登录信息"
 */
- (BOOL)checkOfflineUserInfoUsername:(NSString*)username password:(NSString*)passward;

/**
 *  返回"9宫格"功能列表
 */
- (NSArray*)getFunctionListWithUsername:(NSString*)username;

/**
 *  现有功能及缓存大小
 */
- (NSArray*)getFunctionListAndContentSize;

/**
 *  单个缓存大小
 */
- (NSString*)contentSizeOfCacheForFunctionName:(NSString*)funcname;

/**
 *  删除缓存
 */
- (BOOL)deleteFunctionFileWithFunctionName:(NSString*)funcname;

/**
 *  最后一次登录的response
 */
- (NSDictionary*)getLastLoginResponseWithUsername:(NSString*)username;

/**
 *  离线回调(取)
 */
- (NSDictionary*)recordUrl:(NSString*)url andParam:(NSDictionary*)param;

/**
 *  重置
 */
- (void)reSet;








@end
