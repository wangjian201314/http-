//
//  HttpCommon+Session.m
//  UICommon
//
//  Created by xiuyuan on 2018/9/1.
//  Copyright © 2018年 YN. All rights reserved.
//

#import "HttpCommon+Session.h"
#import "MTURLSessionManager.h"
#import "MTFileManager.h"
@implementation HttpCommon (Session)

#pragma mark - 全自定义
/**
 *  使用分类重写 HttpCommon 的全自定义方法, 拦截旧方法实现
 */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"//忽略protocol警告问题
- (void)requestWithURL:(NSString *)uri
                Params:(NSDictionary *)params
           LoadingHint:(NSString *)loadingHint
              DoneHint:(NSString *)doneHint
               Handler:(MessageHandler)handler
        timeOutHandler:(MessageTimeOutHandler)timeOutHandler
                 isZip:(BOOL)isZip
         customSuccess:(BOOL)customSuccess
{
    
    // 1. 离线回调==========================================
    if ([self responseToOffline:uri params:params handler:handler]) {
        return ;
    }
    
    // 2. 请求地址==========================================
    NSString *urlStr = [self requestUrlWithUri:uri];
    if (!urlStr) {
        return ;
    }
    
    // 3. 等待状态==========================================
    [self requestWithLoadingHint:loadingHint];
    
    // 4. 请求参数==========================================
    NSMutableDictionary *requestParams = [self defaultRequestParams:params uri:uri];
    
    // 5. 请求体============================================
    NSMutableURLRequest *request = [self urlRequestWithUrl:urlStr requestParams:requestParams isZip:isZip];
    
    // 6. 发起请求===========================================
    MTURLSessionManager *manager = [[MTURLSessionManager alloc] init];
    __weak typeof(self) weakself = self;
    NSURLSessionTask *task = [manager dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
#ifdef DEBUG
//        if([urlStr containsString:@"QueryDevice.mt"])
//            responseObject = @{@"result":@"您长时间未操作或者网络超时，请重新登录", @"success":@2};
#endif
        NSString *responseStr = [NSString stringWithFormat:@"\n【response】\n【uri】\t > %@\n【response】> %@", uri, [responseObject JSONString]];
        [MTFileManager recordNetRequest:responseStr fileBody:MTFileBody_Center];
        [MTFileManager recordNetRequest:nil fileBody:MTFileBody_End];
        DLog(@"%@", responseStr);
        
        // 还原超时设置
        weakself.timeout = MTRequestTimeOut;
        
        // 处理数据（移植旧版逻辑）
        if (responseObject) {
            // 处理成功则回调数据，失败则不回调
            if (![weakself processResponseDataWithURL:uri
                                               Params:requestParams
                                          LoadingHint:loadingHint
                                             DoneHint:doneHint
                                              Handler:handler
                                       timeOutHandler:timeOutHandler
                                                isZip:isZip
                                        customSuccess:customSuccess
                                             response:response
                                       responseObject:responseObject
                                                error:error]) {
                return ;
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (loadingHint) {
                    //                    [SVProgressHUD dismiss];//有可能在请求外自己添加了HUD
                    [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"网络连接超时,请检查网络是否可用", nil)];
                }
            });
        }
        
        // 回调数据
        if (handler) {
            handler(responseObject);
        }
    }];
    [task resume];
    
    // 7. 打印请求信息=============================================
    NSString *requestStr = [NSString stringWithFormat:@"\n【request】\n【url】\t > %@\n【params】> %@", urlStr, [requestParams JSONString]];
    [MTFileManager recordNetRequest:requestStr fileBody:MTFileBody_Begin];
    DLog(@"%@", requestStr);
}
#pragma clang diagnostic pop


#pragma mark - 请求配置
#pragma mark -- 离线回调
- (BOOL)responseToOffline:(NSString *)uri
                   params:(NSDictionary *)params
                  handler:(MessageHandler)handler
{
    NSDictionary * offlineResponse = [[MTOfflineManager shareManager] recordUrl:uri andParam:params];
    if (offlineResponse) {
        if ([offlineResponse isEqualToDictionary:@{}]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showErrorWithStatus:@"暂无离线数据"];
            });
            handler(nil);
            return YES;
        }
        handler(offlineResponse);
        return YES;
    }
    return NO;
}

#pragma mark -- 提示信息
- (void)requestWithLoadingHint:(NSString *)loadingHint
{
    if (loadingHint) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:loadingHint maskType:SVProgressHUDMaskTypeBlack];
        });
    }
}

#pragma mark -- 请求地址
- (NSString *)requestUrlWithUri:(NSString *)uri
{
    BOOL useHttps = [[[NSBundle mainBundle].infoDictionary objectForKey:@"USEHTTPS"] boolValue];
    NSString *urlStr = nil;
    if ([uri hasPrefix:@"http://"] || [uri hasPrefix:@"https://"]) {
        urlStr=uri;
    }
    else
    {
        if(useHttps) {
            urlStr= [NSString stringWithFormat:@"https://%@%@", self.serverAddress, uri];
        } else {
            urlStr= [NSString stringWithFormat:@"http://%@%@", self.serverAddress, uri];
        }
    }
    return urlStr;
}


#pragma mark -- 请求参数
- (NSMutableDictionary *)defaultRequestParams:params
                                          uri:(NSString *)uri
{
    // 添加外部传进来的参数
    NSMutableDictionary *requestParams = [params mutableCopy];
    
    if (!requestParams) {
        requestParams = [NSMutableDictionary dictionary];
    }
    
    // 添加默认参数
    [requestParams setObject:[UIDevice currentDevice].imei forKey:@"imei"];
    if (![requestParams.allKeys containsObject:@"imsi"]) {
        [requestParams setObject:[UIDevice currentDevice].imsi forKey:@"imsi"];
    }
    if (![requestParams.allKeys containsObject:@"submittime"]) {
        [requestParams setObject:[[NSDate currentDateString] urlEncode] forKey:@"submittime"];
    }
    if (![requestParams.allKeys containsObject:@"model"]) {
        [requestParams setObject:[UIDevice currentDevice].platformName forKey:@"model"];//手机型号
    }
    if (![requestParams.allKeys containsObject:@"workType"]) {
        [requestParams setObject:[UIDevice currentDevice].networkType forKey:@"workType"];//网络类型
    }
    if (![requestParams.allKeys containsObject:@"osversion"]) {
        [requestParams setObject:[UIDevice currentDevice].systemVersion forKey:@"osversion"];//手机系统
    }
    if (![requestParams.allKeys containsObject:@"osname"]) {
        [requestParams setObject:@"iOS" forKey:@"osname"];//手机系统类型
    }
    if (![requestParams.allKeys containsObject:@"version"]) {
        [requestParams setObject:[UIDevice currentDevice].version forKey:@"version"];//软件版本
    }
    if (![requestParams.allKeys containsObject:@"token"]) {
        [requestParams setObject:[UIDevice currentDevice].token forKey:@"token"];//token
    }
    if (![requestParams.allKeys containsObject:@"mt_token"]) {
        [requestParams setObject:[UIDevice currentDevice].mt_token forKey:@"mt_token"];//token
    }
    
    //这些信息不应该在这里添加
    if ([uri containsString:@"DWGL"] &&
        ![uri containsString:@"DWGL_APP"] &&
        ![requestParams.allKeys containsObject:@"dwzzb_token"]) {
        [requestParams setObject:isnull([[MTGlobalInfo sharedInstance] getAttribute:@"dwzzb_token"]) forKey:@"dwzzb_token"];//token
    }
    
    if (![requestParams.allKeys containsObject:@"logincode"]) {
        NSString * logincode = [[NSUserDefaults standardUserDefaults] objectForKey:@"username"];
        if (logincode) {
            //用于检验同时间仅有一台手机在使用账号
            [requestParams setObject:logincode forKey:@"logincode"];
        }
    }
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
    if ([self respondsToSelector:@selector(addSpecialparams:)]) {
        [self performSelector:@selector(addSpecialparams:) withObject:requestParams];
    }
#pragma clang diagnostic pop
    
    return requestParams;
}


#pragma mark -- 请求体
- (NSMutableURLRequest *)urlRequestWithUrl:(NSString *)urlStr
                             requestParams:(NSDictionary *)requestParams
                                     isZip:(BOOL)isZip
{
    NSArray *urlArray = [urlStr componentsSeparatedByString:@"?"];
    NSString *pureUrl = urlArray[0];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:pureUrl]
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:10.0];
    
    // HTTPMethod
    [request setHTTPMethod:@"POST"];
    
    // HTTPHeaderField
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setValue:@"utf-8" forHTTPHeaderField:@"Accept-Language"];
    
    // Timeout
    [request setTimeoutInterval:self.timeout==0?MTRequestTimeOut:self.timeout];
    
    // cookies
    NSMutableArray  * cookies       = [HttpCommon sharedInstance].cookies;
    NSDictionary    * cookieDict    = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
    
    if (cookies.count == 0) {
        [request setValue:@"" forHTTPHeaderField:@"Cookie"];
        DLog(@"发送的cookie为空");
    } else {
        NSMutableString * cookiesStr = [[NSMutableString alloc]initWithString:@""];
        for (NSInteger i = 0; i < cookies.count; i ++) {
            NSHTTPCookie * cookie = cookies[i];
            [cookiesStr appendFormat:@"%@%@",
             cookiesStr.length?@" ":@"",
             [NSString stringWithFormat:@"%@=%@;",cookie.name,cookie.value]];
        }
        [request setValue:cookiesStr forHTTPHeaderField:@"Cookie"];
        DLog(@"发送的cookie:%@",cookieDict);
    }
    
    // HTTPBody
    NSMutableString *paramsStr = nil;
    if ((requestParams != nil && [requestParams count] > 0) || [urlArray count]>1) {
        NSMutableString *tempStr = [NSMutableString string];
        if([urlArray count]>1){
            [tempStr appendString:urlArray[1]];
            if([urlArray[1] length]>0 && ![urlArray[1] hasSuffix:@"&"]){
                [tempStr appendString:@"&"];
            }
        }
        NSArray *keys = [requestParams allKeys];
        for (int i = 0; i < [keys count]; i++) {
            NSString* key = [keys objectAtIndex:i];
            NSString* value = [NSString stringWithFormat:@"%@",[requestParams valueForKey:key]];
            [tempStr appendString:[NSString stringWithFormat:@"%@=%@&", key, value]];
        }
        
        paramsStr = [NSMutableString stringWithString:[tempStr substringToIndex:[tempStr length] - 1]];
    }
    
    if (paramsStr != nil) {
        if (isZip) {
            [request setHTTPBody:[[paramsStr dataUsingEncoding:NSUTF8StringEncoding] gzippedData]];
        }
        /*2018 9 18 修订:
         xzz 在这里发现有一种情况 或者多种情况 后台接不到body 为啥呢？ 因为后台会根据请求头中 type 和 MTZIP 值去判断是否对body 进行解密如果没有type 也没有 MTZIP 而且这个时候客户端并没有对 body进行加密 那就可能导致 后台取不到body的值
         */
        else    // 默认是 MTZIP 格式
        {
            NSData* paramsStrData = [paramsStr dataUsingEncoding:NSUTF8StringEncoding];
            NSData* data= [self dataEncode:paramsStrData];
            
            [request setValue:@"application/mtzip" forHTTPHeaderField:@"Content-Type"];
            [request setHTTPBody:[data gzippedData]];
        }
    }
    return request;
}

// 压缩包请求体加密
- (NSData *)dataEncode:(NSData *)data {
    if (data == nil) {
        return nil;
    }
    
    Byte *byte = (Byte *)[data bytes];
    for (int i = 0; i < [data length]; i++) {
        *(byte+i) = *(byte+i) + 8;
    }
    return [NSData dataWithBytes:byte length:[data length]];
}


#pragma mark - 响应处理
#pragma mark -- Cookies
- (void)saveMTCookies:(NSHTTPURLResponse *)response
{
    NSDictionary *files = response.allHeaderFields;
    NSString *rtCookie = files[@"Set-Cookie"];
    DLog(@"返回的cookie:%@",rtCookie);
    if (rtCookie) {
        
        //对cookie内的每一项只进行替换
        NSArray * cookies = [NSHTTPCookie cookiesWithResponseHeaderFields:files forURL:response.URL];
        NSMutableArray * tempCookie = [[NSMutableArray alloc] initWithArray:[HttpCommon sharedInstance].cookies];
        
        //遍历新cookies
        for (NSInteger i = 0; i < cookies.count; i ++) {
            NSHTTPCookie * newCookie = cookies[i];
            NSString * newName = newCookie.name;
            
            //手动管理我公司session
            if ([newName isEqualToString:@"JSESSIONID"]) {
                [HttpCommon sharedInstance].lastSession = newCookie;
                continue;
            }
            
            BOOL exist = NO;
            for (NSInteger j = 0; j < tempCookie.count; j ++) {
                NSHTTPCookie * oldCookie = tempCookie[j];
                NSString * oldName = oldCookie.name;
                if ([newName isEqualToString:oldName]) {
                    [tempCookie replaceObjectAtIndex:j withObject:newCookie];
                    exist = YES;
                }
            }
            
            if (exist == NO) {
                [tempCookie addObject:newCookie];
            }
        }
        
        [HttpCommon sharedInstance].cookies = tempCookie;
    }
}

#pragma mark -- process
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
/// 里面的很多处理过程需要直接使用主类里面的逻辑，故使用 performSelector 方法执行
- (BOOL)processResponseDataWithURL:(NSString *)uri
                            Params:(NSDictionary *)requestParams
                       LoadingHint:(NSString *)loadingHint
                          DoneHint:(NSString *)doneHint
                           Handler:(MessageHandler)handler
                    timeOutHandler:(MessageTimeOutHandler)timeOutHandler
                             isZip:(BOOL)isZip
                     customSuccess:(BOOL)customSuccess
///上面为请求数据
///
///下面为返回的数据
                          response:(NSURLResponse *)response
                    responseObject:(id)responseObject
                             error:(NSError *)error
{
    // 保存cookies
    if (requestParams[@"isNotSave"]) {
        [self saveMTCookies:(NSHTTPURLResponse *)response];
    }
    
    [self performSelector:@selector(handleMTToken:) withObject:responseObject];
    
    int retValue = [[responseObject objectForKey:@"success"] intValue];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (customSuccess) {    //自定义处理过程不做任何处理
            if(loadingHint) {
                [SVProgressHUD dismiss];
            }
        } else if (retValue == HTTP_STATE_CALL_SUCCESS) {   //默认处理逻辑
            if (doneHint) {
                [SVProgressHUD showSuccessWithStatus:doneHint];
            } else if(loadingHint) {
                [SVProgressHUD dismiss];
            }
            //记录回调
            [[MTOfflineManager shareManager] saveResponse:responseObject withUrl:uri andParam:requestParams];
        } else if (retValue == HTTP_STATE_SESSION_INVALID){
            //TODO: 这个并不是超时，是重新登录提示，且框架中对这个方法的处理不太合理，做以下修订
            NSString *res = [responseObject objectForKey:@"result"];
            void(^reloginHandler)(BOOL)  = ^(BOOL reloginAcceptedAndSuccess){
                NSDictionary* reloginSuccessResp = @{@"success":@(HTTP_STATE_SESSION_INVALID),
                                                     @"result":@"长时间未操作，已重新登录成功，请重新操作"};
                if(handler)
                    handler(reloginAcceptedAndSuccess ? reloginSuccessResp : responseObject);
                else
                    [SVProgressHUD showErrorWithStatus:NSLocalizedString(res, )];
            };
            [self performSelector:@selector(backGroundReloginHandler:) withObject:reloginHandler];
            
        } else if (retValue == HTTP_STATE_WAIT_REPEAT){
            [[NSNotificationCenter defaultCenter]postNotificationName:@"logoutAction" object:nil userInfo:nil];
            [SVProgressHUD dismiss];
            //截断(在主队列里面，后面本来就没代码了，没意义的截断)
            return;
        } else {
            
            if ([self httpCommonUnAutoTipWhiteListContainUrl:uri]) {
                return ;
            }
            NSString *res = [responseObject objectForKey:@"result"];
            //有些项目不需要弹出这种错误提示框
            if (!res || res.length==0) {
                res = @"后台返回错误，错误信息为空";
            }
            [SVProgressHUD showErrorWithStatus:NSLocalizedString(res, )];
        }
    });
    
    if (retValue == HTTP_STATE_SESSION_INVALID && timeOutHandler) {
        return NO;
    }
    
    if (!requestParams[@"isNotSave"]) {
        [self performSelector:@selector(updateSessionID)];
    }
    return YES;
}
#pragma clang diagnostic pop

/**
 判断网址是否在不需要弹窗提示错误信息的白名单里面

 @param url url 没有前缀的域名的
 @return 返回yes 不弹窗 返回no 需要弹出框
 */
- (BOOL)httpCommonUnAutoTipWhiteListContainUrl:(NSString *)url{
    //MTHTTPCommonUnAutoTipWhiteList
    NSString *plistPath = [[NSBundle mainBundle] pathForResource:@"Info" ofType:@"plist"];
    NSDictionary *infoDict = [[NSDictionary alloc] initWithContentsOfFile:plistPath];
    NSArray *whiteListArr = [infoDict objectForKey:@"MTHTTPCommonUnAutoTipWhiteList"];
    if ([whiteListArr containsObject:url]){
        return YES;
    }
    return NO;
}

@end
