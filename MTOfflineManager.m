//
//  MTOfflineManager.m
//  UICommon
//
//  Created by kingste on 16/9/5.
//  Copyright © 2016年 YN. All rights reserved.
//

#import "MTOfflineManager.h"
#import "MTUtils.h"

#define OFFLINE @"Offline"
#define OFFLINEPACKNAME @"Offline"
#define OFFLINERESPONSE @"OfflineResponse"
#define PLISTNAME @"OfflineFunction"

#define ABANDONARR @[@"begintime",@"endtime"]

@interface MTOfflineManager () {
    /** 文件管理器 */
    NSFileManager * _fileManager;
    
    /** 离线总目录路径 */
    NSString * _offlineMainPath;
    /** 用户离线路径 */
    NSString * _userOffLineFilePath;
}

@end

@implementation MTOfflineManager

//单例
+ (MTOfflineManager *)shareManager {
    static MTOfflineManager * instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MTOfflineManager alloc]init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _isActive = NO;
        _isAllowOffline = NO;
        
        BOOL allowOffline = [[MTGlobalInfo sharedInstance].appInfoDict valueForKey:@"Offline"];
        if (allowOffline) {
            _isAllowOffline = allowOffline;
        }
        
        //fileManager
        _fileManager = [NSFileManager defaultManager];
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *path = [paths objectAtIndex:0];
        NSLog(@"%@",path);
        //离线总目录
        _offlineMainPath = [path stringByAppendingPathComponent:OFFLINEPACKNAME];
        
        BOOL exist = [_fileManager fileExistsAtPath:_offlineMainPath];
        if (exist == NO) {
            NSError * error = nil;
            exist = [_fileManager createDirectoryAtPath:_offlineMainPath withIntermediateDirectories:NO attributes:nil error:&error];
            if (error) {
                NSLog(@"创建离线根目录失败:%@",error);
            }
        }
    }
    return self;
}




#pragma mark - setter
- (void)setUserID:(NSString *)userID {
    _userID = userID;
    
    //检验用户离线文件夹
    _userOffLineFilePath = [_offlineMainPath stringByAppendingPathComponent:userID];
    BOOL exist = [_fileManager fileExistsAtPath:_userOffLineFilePath];
    if (exist == NO) {
        NSError * error = nil;
        exist = [_fileManager createDirectoryAtPath:_userOffLineFilePath withIntermediateDirectories:NO attributes:nil error:&error];
        if (error) {
            NSLog(@"创建离线根目录失败:%@",error);
        }
    }
}

- (void)setCurrentFunc:(NSString *)currentFunc {
    _currentFunc = currentFunc;
    if (_isAllowOffline&&_isActive==NO) {
        _currentFunc = currentFunc;
    }
}

#pragma mark - getter
- (NSArray *)supportFuncs {
    if (_supportFuncs) {
        return _supportFuncs;
    }
    
    //三个数据源(暂时支持三个)
    NSDictionary * response = [[MTOfflineManager shareManager] getLastLoginResponseWithUsername:nil];
    //app支持的离线模块
    NSDictionary * offlineDict = response[@"portalConfig"][@"offline"];
    if (offlineDict == nil) {
        NSString * path = [[NSBundle mainBundle] pathForResource:@"tempOfflineFunction" ofType:@"plist"];
        offlineDict = [[NSDictionary alloc] initWithContentsOfFile:path];
    }
    return [offlineDict allKeys];
}

#pragma mark - reSet
- (void)reSet {
    _currentFunc = nil;
    _isActive = NO;
}

#pragma mark - 验证离线登录信息
- (BOOL)checkOfflineUserInfoUsername:(NSString*)username password:(NSString*)passward {
    NSDictionary * offlineDict = [[NSUserDefaults standardUserDefaults] valueForKey:OFFLINE];
    if (offlineDict == nil) {
        return NO;
    }else{
        NSArray * userAndPwd = @[username,passward];
        NSArray * allUserAndPwds = [offlineDict allValues];
        for (NSInteger i = 0; i <allUserAndPwds.count; i ++) {
            NSArray * userAndPwds = allUserAndPwds[i];
            if ([userAndPwds containsObject:userAndPwd]) {
                self.userID = [offlineDict allKeys][i];
                return YES;
                break;
            }
        }
        return NO;
    }
    return NO;
}

#pragma mark - 更新用户离线账户
- (BOOL)updateOfflineUserInfoUsername:(NSString*)username password:(NSString*)passward andResponse:(NSDictionary*)response {
    
    //在线登录后记录用户信息及开辟离线文件夹
    //用户唯一标示ID
    NSString * userID = response[@"userid"]?response[@"userid"]:nil;
    if (userID == nil) {
        return NO;
    }
    self.userID = userID;
    
    //保存 response    =========================================================================
    NSDictionary * Response = [[NSUserDefaults standardUserDefaults] valueForKey:OFFLINERESPONSE];
    if (Response == nil) {
        //第一次使用
        NSMutableDictionary * firstTimeResponse = [@{userID:[response JSONString]} mutableCopy];
        [[NSUserDefaults standardUserDefaults] setObject:firstTimeResponse forKey:OFFLINERESPONSE];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }else{
        //非第一次使用
        NSMutableDictionary * offlineResponse = [NSMutableDictionary dictionaryWithDictionary:Response];
        [offlineResponse setValue:[response JSONString] forKey:userID];
        [[NSUserDefaults standardUserDefaults] setObject:offlineResponse forKey:OFFLINERESPONSE];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    //保存账号密码      =========================================================================
    NSArray * userAndPwd = @[username,passward];
    NSDictionary * offlineDict = [[NSUserDefaults standardUserDefaults] valueForKey:OFFLINE];
    if (offlineDict == nil) {
        //第一次使用
        NSMutableDictionary * firstTimeDict = [@{userID:@[userAndPwd]} mutableCopy];
        [[NSUserDefaults standardUserDefaults] setObject:firstTimeDict forKey:OFFLINE];
        BOOL ret = [[NSUserDefaults standardUserDefaults] synchronize];
        return ret;
    }else{
        //非第一次使用
        NSArray * allIDs = [offlineDict allKeys];
        if ([allIDs containsObject:userID]) {
            //账号非第一次登录
            NSArray * userAndPwds = [offlineDict objectForKey:userID];
            if ([userAndPwds containsObject:userAndPwd]) {
                return YES;
            }else {
                NSMutableDictionary * offlineMuDict = [NSMutableDictionary dictionaryWithDictionary:offlineDict];
                NSMutableArray * newUserAndPwds = [NSMutableArray arrayWithArray:offlineDict[userID]];
                //删除用户名相同的账号(用户可能修改过密码)
                for (NSInteger i = 0; i < newUserAndPwds.count; i ++) {
                    NSArray * itemArr = newUserAndPwds[i];
                    if ([itemArr.firstObject isEqualToString:userAndPwd.firstObject]) {
                        [newUserAndPwds removeObject:itemArr];
                    }
                }
                [newUserAndPwds addObject:userAndPwd];
                [offlineMuDict setValue:newUserAndPwds forKey:userID];
                [[NSUserDefaults standardUserDefaults] setObject:offlineMuDict forKey:OFFLINE];
                BOOL ret = [[NSUserDefaults standardUserDefaults] synchronize];
                return ret;
            }
        }else{
            //账号第一次登录
            NSMutableDictionary * offlineMuDict = [NSMutableDictionary dictionaryWithDictionary:offlineDict];
            [offlineMuDict setValue:@[userAndPwd] forKey:userID];
            [[NSUserDefaults standardUserDefaults] setObject:offlineMuDict forKey:OFFLINE];
            BOOL ret = [[NSUserDefaults standardUserDefaults] synchronize];
            return ret;
        }
        BOOL ret = [[NSUserDefaults standardUserDefaults] synchronize];
        return ret;
    }
    return NO;
}

#pragma mark - 功能列表
- (NSArray*)getFunctionListWithUsername:(NSString*)username {
    
    NSString * path = [[NSBundle mainBundle] pathForResource:PLISTNAME ofType:@"plist"];
    NSMutableDictionary * allFuncList = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
    
    if (allFuncList == nil)return @[];
    
    //整理现有缓存功能
    NSMutableArray * haveSavedFuncs  = [NSMutableArray arrayWithArray:[_fileManager subpathsAtPath:_userOffLineFilePath]];
    for (NSInteger i = 0; i < haveSavedFuncs.count; i ++) {
        NSString * itemStr = haveSavedFuncs[i];
        if ([itemStr hasSuffix:@".plist"]) {
            [haveSavedFuncs replaceObjectAtIndex:i withObject:[[itemStr componentsSeparatedByString:@".plist"] firstObject]];
        }else{
            [haveSavedFuncs removeObjectAtIndex:i];
            i--;
        }
    }
    
    //无缓存的删除
    NSMutableArray * existFuncs = [NSMutableArray new];
    for (NSInteger i =0 ; i < [allFuncList allKeys].count; i ++) {
        NSString * itemKey = [allFuncList allKeys][i];
        if ([haveSavedFuncs containsObject:itemKey]) {
            [existFuncs addObject:[allFuncList objectForKey:itemKey]];
        }
    }
    return existFuncs;
}

/**
 *  现有功能及缓存大小
 */
- (NSArray*)getFunctionListAndContentSize {
    NSString * path = [[NSBundle mainBundle] pathForResource:PLISTNAME ofType:@"plist"];
    NSMutableDictionary * allFuncList = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
    
    if (allFuncList == nil)return @[];
    
    //整理现有缓存功能
    NSMutableArray * haveSavedFuncs  = [NSMutableArray arrayWithArray:[_fileManager subpathsAtPath:_userOffLineFilePath]];
    for (NSInteger i = 0; i < haveSavedFuncs.count; i ++) {
        NSString * itemStr = haveSavedFuncs[i];
        if ([itemStr hasSuffix:@".plist"]) {
            [haveSavedFuncs replaceObjectAtIndex:i withObject:[[itemStr componentsSeparatedByString:@".plist"] firstObject]];
        }else{
            [haveSavedFuncs removeObjectAtIndex:i];
            i--;
        }
    }
    
    //无缓存的删除
    NSMutableArray * existFuncs = [NSMutableArray new];
    for (NSInteger i =0 ; i < [allFuncList allKeys].count; i ++) {
        NSString * itemKey = [allFuncList allKeys][i];
        if ([haveSavedFuncs containsObject:itemKey]) {
            NSMutableDictionary * itemDict = [NSMutableDictionary dictionaryWithDictionary:allFuncList[itemKey]];
            //计算单个缓存大小(KB)
            NSString * contentSize = [self contentSizeOfCacheForFunctionName:itemKey];
            [itemDict setObject:contentSize forKey:@"size"];
            [existFuncs addObject:itemDict];
        }
    }
    
    return existFuncs;
}

/**
 *  单个缓存大小
 */
- (NSString*)contentSizeOfCacheForFunctionName:(NSString*)funcname {
    
    //完整路径
    NSString * path = [_userOffLineFilePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@",funcname,@".plist"]];
    BOOL exists = [_fileManager fileExistsAtPath:path];
    if (exists == NO) {
        return @"0.00KB";
    }
    NSError * error;
    NSDictionary * attr = [_fileManager attributesOfItemAtPath:path error:&error];
    if (error) {
        NSLog(@"error:%@",error);
    }
    
    CGFloat size = [attr[NSFileSize] floatValue];
    NSString * sizeKB = [NSString stringWithFormat:@"%.2f%@",size/1024.0,@"KB"];
    
    return sizeKB;
}

#pragma mark - 删除缓存
- (BOOL)deleteFunctionFileWithFunctionName:(NSString*)funcname {
    if (funcname == nil) {
        NSLog(@"传入值为空");
        return NO;
    }
    
    NSString * fileName = [NSString stringWithFormat:@"%@.plist",funcname];
    NSString * path = [_userOffLineFilePath stringByAppendingPathComponent:fileName];
    BOOL exists = [_fileManager fileExistsAtPath:path];
    if (exists == NO) {
        return YES;
    }
    NSError * error;
    BOOL ret = [_fileManager removeItemAtPath:path error:&error];
    if (ret) {
        return YES;
    }
    if (error) {
        NSLog(@"删除缓存出错:%@",error);
    }
    return NO;
}

#pragma mark - 获取最新的登陆回调
- (NSDictionary*)getLastLoginResponseWithUsername:(NSString*)username {
    NSDictionary * Response = [[NSUserDefaults standardUserDefaults] valueForKey:OFFLINERESPONSE];
    if (Response == nil)return nil;
    NSString * lasetReponseStr = Response[self.userID];
    return [lasetReponseStr objectFromJSONString];
}

#pragma mark =========== 存 ===========
- (void)saveResponse:(NSDictionary*)response withUrl:(NSString*)url andParam:(NSDictionary*)param {
    //为"离线版本"
    if (_isAllowOffline){
        //"离线模式"或无"功能状态"无需存储
        if (_isActive||_currentFunc ==nil) {
            return;
        }
        
        NSString * key = [self makeKeyWithUrl:url andParam:param];
        NSString * path = [_userOffLineFilePath stringByAppendingPathComponent:_currentFunc];
        path = [NSString stringWithFormat:@"%@%@",path,@".plist"];
        BOOL exist = [_fileManager fileExistsAtPath:path];
        dispatch_async(dispatch_get_main_queue(), ^{
            BOOL result;
            if (exist == NO) {
                NSMutableDictionary * data = [NSMutableDictionary dictionaryWithDictionary:@{}];
                [data setObject:[MTUtils base64StringFromText:[response JSONString]] forKey:key];
                result = [data writeToFile:path atomically:YES];
            }else{
                NSMutableDictionary * data = [NSMutableDictionary dictionaryWithContentsOfFile:path];
                if ([[data allKeys]containsObject:key]) {
                    [data removeObjectForKey:key];
                }
                [data setObject:[MTUtils base64StringFromText:[response JSONString]] forKey:key];
                result = [data writeToFile:path atomically:YES];
            }
            NSLog(@"回调存储:%@",result?@"成功":@"失败");
        });
    }
}

#pragma mark =========== 取 ===========
- (NSDictionary*)recordUrl:(NSString*)url andParam:(NSDictionary*)param {
    if (_isAllowOffline&&_isActive) {
        
        NSString * key = [self makeKeyWithUrl:url andParam:param];
        NSString * path = [_userOffLineFilePath stringByAppendingPathComponent:_currentFunc];
        path = [NSString stringWithFormat:@"%@%@",path,@".plist"];
        BOOL exist = [_fileManager fileExistsAtPath:path];
        if (exist) {
            NSMutableDictionary * data = [NSMutableDictionary dictionaryWithContentsOfFile:path];
            if ([[data allKeys] containsObject:key]) {
                return [[MTUtils textFromBase64String:[data objectForKey:key]] objectFromJSONString];
            }else{
                return @{};
            }
        }else{
            return @{};
        }
    }
    return nil;
}

#pragma mark - 数据处理
- (NSString *)makeKeyWithUrl:(NSString*)url andParam:(NSDictionary*)param {
    if (param == nil||[param isEqualToDictionary:@{}]) {
        return url;
    }
    
    //移除日期参数以便在不同时间可以匹配到离线数据
    NSMutableDictionary * clearDict = [NSMutableDictionary dictionaryWithDictionary:param];
    for (NSInteger i = 0; i < ABANDONARR.count; i ++) {
        NSString * item = ABANDONARR[i];
        if ([[clearDict allKeys]containsObject:item]) {
            [clearDict removeObjectForKey:item];
        }
    }
    
    NSMutableString * lastStr = nil;
    NSMutableString * tempStr = [NSMutableString stringWithString:url];
    NSRange range = [tempStr rangeOfString:@"?"];
    if(range.location == NSNotFound) {
        [tempStr appendString:@"?"];
    }else{
        if (![tempStr hasPrefix:@"&"]) {
            [tempStr appendString:@"&"];
        }
    }
    
    for (NSInteger i = 0; i < [clearDict allKeys].count; i ++) {
        NSString* key = [[clearDict allKeys] objectAtIndex:i];
        NSString* value = [NSString stringWithFormat:@"%@",[clearDict valueForKey:key]];
        [tempStr appendString:[NSString stringWithFormat:@"%@=%@&", key, value]];
        
    }
    lastStr = [NSMutableString stringWithString:[tempStr substringToIndex:[tempStr length] - 1]];
    return lastStr;
}

//- (NSString*)countFileSizeWithItemKey:(NSString*)itemKey {
//    
//    //完整路径
//    NSString * path = [_userOffLineFilePath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@%@",itemKey,@".plist"]];
//    BOOL exists = [_fileManager fileExistsAtPath:path];
//    if (exists == NO) {
//        return @"0.00KB";
//    }
//    NSError * error;
//    NSDictionary * attr = [_fileManager attributesOfItemAtPath:path error:&error];
//    if (error) {
//        NSLog(@"error:%@",error);
//    }
//    
//    CGFloat size = [attr[NSFileSize] floatValue];
//    NSString * sizeKB = [NSString stringWithFormat:@"%.2f%@",size/1024.0,@"KB"];
//    
//    return sizeKB;
//}

@end




























