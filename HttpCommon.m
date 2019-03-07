//
//  HttpCommon.m
//  MTNOP
//
//  Created by renwanqian on 14-4-16.
//  Copyright (c) 2014年 cn.mastercom. All rights reserved.
//
//  李金 2016.9.9 - requestWithURL:uri Params:params LoadingHint:loadingHint DoneHint:doneHint Handler:handler isZip:isZip:新增离线缓存
//


#import "HttpCommon.h"
#import "HttpCommonOperation.h"
#import "MTFileManager.h"
#import "HttpCommon+Session.h"

@interface HttpCommon ()

@property (nonatomic, strong) NSMutableArray *cerFiles;

@end


#define TIMEOUT 90
@implementation HttpCommon
{
    NSInteger _timeout;
    
    /** 重登录 */
    NSDate  * _lastRelogionDate;        //记录最后一次重登录的时间
    NSDate  * _relogionSuccessDate;        //记录最后一次重登录的时间
    NSMutableArray * _willDealBlocks;   //用于保存重登陆过程中需校验session的block
}
static NSString *const DEFAULT_TIPS = @"正在加载...";
static NSString *const DEFAULT_UPLOAD_TIPS = @"正在提交...";

- (id)init {
    self = [super init];
    if (self) {
        _cookies  = [[NSMutableArray alloc]init];
        _timeout=TIMEOUT;
        _opreationQueue = [[NSOperationQueue alloc] init];
        _opreationQueue.maxConcurrentOperationCount = 5;
    }
    return self;
}

- (id)initWithURL:(NSString *)url {
    self = [super init];
    if (self) {
        self.serverAddress = url;
        _timeout=TIMEOUT;
        _opreationQueue = [[NSOperationQueue alloc] init];
        _opreationQueue.maxConcurrentOperationCount = 5;
    }
    return self;
}

- (void)setMaxConcurrentOperationCount:(NSInteger)maxConcurrentOperationCount {
    _maxConcurrentOperationCount = maxConcurrentOperationCount;
    _opreationQueue.maxConcurrentOperationCount = _maxConcurrentOperationCount;
}

+ (instancetype)sharedInstance {
    static HttpCommon *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[HttpCommon alloc] init];
    });
    sharedInstance.serverAddress = [MTGlobalInfo sharedInstance].SERVER_ADDRESS;
    return sharedInstance;
}

+ (instancetype)sharedInstanceWithURL:(NSString *)url{
    static HttpCommon *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[HttpCommon alloc] initWithURL:url];
    });
    
    return sharedInstance;
}


- (AFSecurityPolicy*)customSecurityPolicy {
    
    
    /**
     *  从NSBundle中导入多张CA证书（Certification Authority，支持SSL证书以及自签名的CA
     */
    NSMutableArray *caArray;
    for (NSString *cerPath in self.cerFiles) {
        NSData* caCert = [NSData dataWithContentsOfFile:cerPath];
        NSCAssert(caCert != nil, @"caCert is nil");
        if(nil == caCert)
            break;
        if(nil == caArray) {
            caArray = [NSMutableArray new];
        }
        [caArray addObject:caCert];
    }
    
    NSCAssert(caArray != nil, @"caArray is nil");
    
    
    /**** SSL Pinning ****/
    AFSecurityPolicy *securityPolicy = [[AFSecurityPolicy alloc] init];
    [securityPolicy setAllowInvalidCertificates:NO];
    [securityPolicy setPinnedCertificates:caArray];
    [securityPolicy setSSLPinningMode:AFSSLPinningModeCertificate];
    /**** SSL Pinning ****/
    
    
    return securityPolicy;
}



 - (void)uploadWithURL:(NSString *)uri Params:(NSDictionary *)params FileURLs:(NSArray *)fileURLs Handler:(MessageHandler)handler {
    
     //1
     BOOL useHttps = [[[NSBundle mainBundle].infoDictionary objectForKey:@"USEHTTPS"] boolValue];
     NSString *urlStr = nil;
     if ([uri hasPrefix:@"http://"]||[uri hasPrefix:@"https://"]) {
         urlStr=uri;
     } else {
         if(useHttps) {
             urlStr= [NSString stringWithFormat:@"https://%@%@", self.serverAddress, uri];
         } else {
             urlStr= [NSString stringWithFormat:@"http://%@%@", self.serverAddress, uri];
         }
     }
     
     
     NSMutableDictionary *requestParams = [params mutableCopy];
     [requestParams setObject:[UIDevice currentDevice].imei forKey:@"imei"];
     [requestParams setObject:[UIDevice currentDevice].imsi forKey:@"imsi"];
     [requestParams setObject:[NSDate currentDateString] forKey:@"submittime"];
     if (![requestParams.allKeys containsObject:@"mt_token"]) {
         [requestParams setObject:[UIDevice currentDevice].mt_token forKey:@"mt_token"];//token
     }
    
     if (![requestParams.allKeys containsObject:@"dwzzb_token"]&&![uri containsString:@"DWGL_APP"]&&[uri containsString:@"DWGL"]) {
         [requestParams setObject:isnull([[MTGlobalInfo sharedInstance] getAttribute:@"dwzzb_token"]) forKey:@"dwzzb_token"];//token
     }
     //特殊参数(在各自项目内使用category复写)
     [self addSpecialparams:requestParams];
     
     
     AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
     if(useHttps) {
         [manager setSecurityPolicy:[self customSecurityPolicy]];
         // 安全验证
         AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
         /*
          AFSSLPinningModeNone: 代表客户端无条件地信任服务器端返回的证书。
          AFSSLPinningModePublicKey: 代表客户端会将服务器端返回的证书与本地保存的证书中，PublicKey的部分进行校验；如果正确，才继续进行。
          AFSSLPinningModeCertificate: 代表客户端会将服务器端返回的证书和本地保存的证书中的所有内容，包括PublicKey和证书部分，全部进行校验；如果正确，才继续进行。
          */
         securityPolicy.allowInvalidCertificates = YES;//是否信任非法证书(自建证书)
         securityPolicy.validatesDomainName = NO;//是否验证域名有效性
         manager.securityPolicy = securityPolicy;
     }
     [manager.requestSerializer setHTTPShouldHandleCookies:YES];
     
     for (NSHTTPCookie * cookie in self.cookies) {
         [manager.requestSerializer setValue:[NSString stringWithFormat:@"%@=%@", [cookie name], [cookie value]] forHTTPHeaderField:@"Cookie"];
     }
     
     
     [manager.requestSerializer setTimeoutInterval:TIMEOUT];
     manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/html",@"application/javascript", nil];
     
     [manager POST:urlStr parameters:requestParams constructingBodyWithBlock: ^(id < AFMultipartFormData > formData) {
         for (id file in fileURLs) {
             if ([file isKindOfClass:[NSURL class]]) {
                 [formData appendPartWithFileURL:file name:[[(NSURL*)file path] lastPathComponent] error:NULL];
             }
             else if ([file isKindOfClass:[NSDictionary class]])
             {
                NSDictionary* dic=(NSDictionary*)file;
                NSData* data=[dic valueForKey:@"data"];
                NSString* name=[dic valueForKey:@"name"];
                NSString* fileName=[dic valueForKey:@"fileName"];
                NSString* mimeType=[dic valueForKey:@"mimeType"];
                [formData appendPartWithFileData:data name:name fileName:fileName mimeType:mimeType];
            }
        }
    } success: ^(AFHTTPRequestOperation *operation, id responseObject) {
        _timeout = TIMEOUT;
        int retValue = -1;
        if(responseObject == nil){
            
            NSData* responseData = [operation.responseData copy];
            responseData = [responseData gunzippedData];
            NSString* responseStr = [self dataDecode:responseData];
            responseObject = [responseStr objectFromJSONString];
            
            handler(responseObject);
        
            return;
        }else if ([responseObject isKindOfClass:[NSDictionary class]]) {
            handler(responseObject);
            
            retValue = [[responseObject objectForKey:@"success"] intValue];
            DLog(@"[Response] >>> %@", [responseObject JSONString]);
        } else if ([responseObject isKindOfClass:[NSData class]]) {
            NSDictionary *response = [responseObject objectFromJSONData];
            handler(response);
            
            retValue = [[response objectForKey:@"success"] intValue];
            DLog(@"[Response] >>> %@", response);
        }
        
        if (retValue != HTTP_STATE_CALL_SUCCESS) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showErrorWithStatus:[responseObject objectForKey:@"result"]];
            });
            
        }
    } failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        _timeout=TIMEOUT;
        handler(nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"网络连接超时,请检查网络是否可用", nil)];
        });
        
    }];
     
     
    DLog(@"[URLStr] >>> %@", urlStr);
    DLog(@"[Params] >>> %@", requestParams);
     
}

- (void)uploadWithURL:(NSString *)uri Params:(NSDictionary *)params FileURLs:(NSArray *)fileURLs Operation:(AFHTTPRequestOp)op Progress:(HandleProgress)progress Handler:(MessageHandler)handler
{
    //1
    BOOL useHttps = [[[NSBundle mainBundle].infoDictionary objectForKey:@"USEHTTPS"] boolValue];
    NSString *urlStr = nil;
    if ([uri hasPrefix:@"http://"]) {
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
    
    
    NSMutableDictionary *requestParams = [params mutableCopy];
    [requestParams setObject:[UIDevice currentDevice].imei forKey:@"imei"];
    [requestParams setObject:[UIDevice currentDevice].imsi forKey:@"imsi"];
    [requestParams setObject:[NSDate currentDateString] forKey:@"submittime"];
    if (![requestParams.allKeys containsObject:@"mt_token"]) {
        [requestParams setObject:[UIDevice currentDevice].mt_token forKey:@"mt_token"];//token
    }
    if (![requestParams.allKeys containsObject:@"dwzzb_token"]&&![uri containsString:@"DWGL_APP"]&&[uri containsString:@"DWGL"]) {
        [requestParams setObject:isnull([[MTGlobalInfo sharedInstance] getAttribute:@"dwzzb_token"]) forKey:@"dwzzb_token"];//token
    }
    
    //特殊参数(在各自项目内使用category复写)
    [self addSpecialparams:requestParams];
    
    
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    if(useHttps) {
        [manager setSecurityPolicy:[self customSecurityPolicy]];
        AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
        /*
         AFSSLPinningModeNone: 代表客户端无条件地信任服务器端返回的证书。
         AFSSLPinningModePublicKey: 代表客户端会将服务器端返回的证书与本地保存的证书中，PublicKey的部分进行校验；如果正确，才继续进行。
         AFSSLPinningModeCertificate: 代表客户端会将服务器端返回的证书和本地保存的证书中的所有内容，包括PublicKey和证书部分，全部进行校验；如果正确，才继续进行。
         */
        securityPolicy.allowInvalidCertificates = YES;//是否信任非法证书(自建证书)
        securityPolicy.validatesDomainName = NO;//是否验证域名有效性
        manager.securityPolicy = securityPolicy;
    }
    [manager.requestSerializer setHTTPShouldHandleCookies:YES];
    
    for (NSHTTPCookie * cookie in self.cookies) {
        [manager.requestSerializer setValue:[NSString stringWithFormat:@"%@=%@", [cookie name], [cookie value]] forHTTPHeaderField:@"Cookie"];
    }
    
    [manager.requestSerializer setTimeoutInterval:TIMEOUT];
    manager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"text/html",@"application/javascript", nil];
    AFHTTPRequestOperation* operation = [manager POST:urlStr parameters:requestParams constructingBodyWithBlock: ^(id < AFMultipartFormData > formData) {
        for (id file in fileURLs) {
            if ([file isKindOfClass:[NSURL class]]) {
                [formData appendPartWithFileURL:file name:[[(NSURL*)file path] lastPathComponent] error:NULL];
            }
            else if ([file isKindOfClass:[NSDictionary class]])
            {
                NSDictionary* dic=(NSDictionary*)file;
                NSData* data=[dic valueForKey:@"data"];
                NSString* name=[dic valueForKey:@"name"];
                NSString* fileName=[dic valueForKey:@"fileName"];
                NSString* mimeType=[dic valueForKey:@"mimeType"];
                [formData appendPartWithFileData:data name:name fileName:fileName mimeType:mimeType];
            }
        }
    } success: ^(AFHTTPRequestOperation *operation, id responseObject) {
        _timeout=TIMEOUT;
        int retValue = -1;
        if(responseObject == nil){
            
            NSData* responseData = [operation.responseData copy];
            responseData = [responseData gunzippedData];
            NSString* responseStr = [self dataDecode:responseData];
            responseObject = [responseStr objectFromJSONString];
            
            handler(responseObject);
            
            return;
        }else if ([responseObject isKindOfClass:[NSDictionary class]]) {
            handler(responseObject);
            
            retValue = [[responseObject objectForKey:@"success"] intValue];
            
            DLog(@"[Response] >>> %@", [responseObject JSONString]);
            
        } else if ([responseObject isKindOfClass:[NSData class]]) {
            NSDictionary *response = [responseObject objectFromJSONData];
            handler(response);
            
            retValue = [[response objectForKey:@"success"] intValue];
            
            DLog(@"[Response] >>> %@", response);
            
        }
        
        if (retValue != HTTP_STATE_CALL_SUCCESS) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showErrorWithStatus:[responseObject objectForKey:@"result"]];
            });
            
        }
    } failure: ^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        _timeout=TIMEOUT;
        handler(nil);
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"网络连接超时,请检查网络是否可用", nil)];
        });
        
    }];
    
    // 取得请求实体
    op(operation);
    
    //[operation resume];
    //[operation pause];
    
    // 上传进度
    [operation setUploadProgressBlock:^(NSUInteger __unused bytesWritten,
                                        long long totalBytesWritten,
                                        long long totalBytesExpectedToWrite) {
        DLog(@"upload-progress---bytesWritten %lld/%lld", totalBytesWritten, totalBytesExpectedToWrite);
        CGFloat pro = (CGFloat)totalBytesWritten/totalBytesExpectedToWrite;
        progress(pro);
    }];
    
    
    DLog(@"[URLStr] >>> %@", urlStr);
    DLog(@"[Params] >>> %@", requestParams);
    
}

+(NSString*) serverAdressWithNoPort{
    
    
    NSString* server= [MTGlobalInfo sharedInstance].SERVER_ADDRESS;
    
    NSRange range = [server rangeOfString:@":"];
    server = [server substringToIndex:NSMaxRange(range)-1];
    
    return server;
}
+(NSString*) serverAdress{
    return [MTGlobalInfo sharedInstance].SERVER_ADDRESS;
}
- (void)setTimeout:(NSInteger) timeout
{
    _timeout=timeout;
}

- (void)cancelAllOperations {
    for (HttpCommonOperation *op in _opreationQueue.operations) {
        [op cancel];
    }
    [_opreationQueue cancelAllOperations];
}

#pragma mark -
#pragma mark - 全自定义簇方法

/**
 *  有三个参数是必填项, 可以为空 但必须传进来
 *  uri     : 资源路径(请求字段)
 *  params  : 请求参数
 *  handler : 数据处理
 */

#pragma mark - MTZip加密(默认)


/**
 *  无提示
 */
- (void)requestNoHintWithURL:(NSString *)uri Params:(NSDictionary *)params Handler:(MessageHandler)handler
{
    [self requestWithURL:uri Params:params LoadingHint:nil DoneHint:nil Handler:handler];
}


/**
 *  默认提示 "正在加载..."
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params Handler:(MessageHandler)handler
{
    [self requestWithURL:uri Params:params LoadingHint:DEFAULT_TIPS DoneHint:nil Handler:handler];
}


/**
 *  自定义提示
 *
 *  @param LoadingHint 提示内容
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint Handler:(MessageHandler)handler
{
    [self requestWithURL:uri Params:params LoadingHint:loadingHint customSuccess:NO Handler:handler];
}


/**
 *  自定义加载提示和自定义处理过程
 *
 *  @param loadingHint      提示内容
 *
 *  @param customSuccess    是否自己处理数据 (框架不做任何逻辑处理,只返回原始数据)
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint customSuccess:(BOOL)customSuccess Handler:(MessageHandler)handler
{
    [self requestWithURL:uri Params:params LoadingHint:loadingHint DoneHint:nil Handler:handler timeOutHandler:nil isZip:NO customSuccess:customSuccess];
}


/**
 *  自定义加载和完成提示
 *
 *  @param loadingHint  提示内容
 *
 *  @param doneHint     完成提示
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler
{
    [self requestWithURL:uri Params:params LoadingHint:loadingHint DoneHint:doneHint Handler:handler timeOutHandler:nil isZip:NO customSuccess:NO];
}


/**
 *  自定义加载提示 -超时重连
 *
 *  @param loadingHint      提示内容
 *
 *  @param timeOutHandler   超时回调, 如果不为空, 超时之后框架会自动重连一次
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint Handler:(MessageHandler)handler timeOutHandler:(MessageTimeOutHandler)timeOutHandler
{
    [self requestWithURL:uri Params:params LoadingHint:loadingHint DoneHint:nil Handler:handler timeOutHandler:timeOutHandler];
}


/**
 *  自定义加载和完成提示 -超时重连
 *
 *  @param loadingHint      提示内容
 *
 *  @param doneHint         完成提示
 *
 *  @param timeOutHandler   超时回调, 如果不为空, 超时之后框架会自动重连一次
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler timeOutHandler:(MessageTimeOutHandler)timeOutHandler
{
    [self requestWithURL:uri Params:params LoadingHint:loadingHint DoneHint:doneHint Handler:handler timeOutHandler:timeOutHandler isZip:NO customSuccess:NO];
}

#pragma mark -- 方法名 requestMTZipWithURL 开头
/**
 *  自定义提示
 *
 *  @param LoadingHint 提示内容
 */
- (void)requestMTGzipWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint Handler:(MessageHandler)handler
{
    [self  requestMTZipWithURL:uri Params:params  LoadingHint:loadingHint DoneHint:nil Handler:handler];
}

- (void)requestMTZipWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint Handler:(MessageHandler)handler
{
    [self  requestMTZipWithURL:uri Params:params  LoadingHint:loadingHint DoneHint:nil Handler:handler];
}


/**
 *  自定义加载和完成提示
 *
 *  这里的方法实现其实跟全自定义里面的是一样的，故应舍弃这里的实现部分，使用全自定义簇方法
 */
- (void)requestMTZipWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler
{
    [self requestWithURL:uri Params:params LoadingHint:loadingHint DoneHint:doneHint Handler:handler timeOutHandler:nil isZip:NO customSuccess:NO];
}


#pragma mark - Zip加密


/**
 *  无任何提示 -gzip
 */
- (void)requestGzipWithURL:(NSString *)uri Params:(NSDictionary *)params Handler:(MessageHandler)handler
{
    [self requestWithURL:uri Params:params LoadingHint:nil DoneHint:nil Handler:handler isZip:YES];
}


/**
 *  自定义加载和完成提示 -gzip
 *
 *  @param loadingHint  提示内容
 *
 *  @param doneHint     完成提示
 *
 *  @param isZip            是否是 zip 加密, 默认是 MTZIP
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler isZip:(BOOL)isZip
{
    [self requestWithURL:uri Params:params LoadingHint:loadingHint DoneHint:doneHint Handler:handler isZip:isZip customSuccess:NO];
}


/**
 *  自定义加载和完成提示 -gzip
 *
 *  @param loadingHint      提示内容
 *
 *  @param doneHint         完成提示
 *
 *  @param isZip            是否是 zip 加密, 默认是 MTZIP
 *
 *  @param customSuccess    是否自己处理数据 (框架不做任何逻辑处理,只返回原始数据)
 */

- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler  isZip:(BOOL)isZip customSuccess:(BOOL)customSuccess
{
    [self requestWithURL:uri Params:params LoadingHint:loadingHint DoneHint:doneHint Handler:handler timeOutHandler:nil isZip:isZip customSuccess:customSuccess];
}


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
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler timeOutHandler:(MessageTimeOutHandler)timeOutHandler isZip:(BOOL)isZip
{
    [self requestWithURL:uri Params:params LoadingHint:loadingHint DoneHint:doneHint Handler:handler timeOutHandler:timeOutHandler isZip:isZip customSuccess:NO];
}


#pragma mark -
#pragma mark - 非自定义簇方法

#pragma mark - 加载图片
/**
 *  加载图片
 *
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageNSDataHandler)handler isImage:(BOOL)isImage{
    if (loadingHint) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:loadingHint];
        });
        
    }
    
    //2
    BOOL useHttps = [[[NSBundle mainBundle].infoDictionary objectForKey:@"USEHTTPS"] boolValue];
    NSString *urlStr = nil;
    if ([uri hasPrefix:@"http://"] || [uri hasPrefix:@"https://"]) {
        urlStr=uri;
    }
    else
    {
        NSDictionary *dic = [NSBundle mainBundle].infoDictionary;
        if(useHttps) {
            urlStr= [NSString stringWithFormat:@"https://%@%@", self.serverAddress, uri];
        } else {
            urlStr= [NSString stringWithFormat:@"http://%@%@", self.serverAddress, uri];
        }
    }
    
    //
    NSMutableDictionary *requestParams = nil;
    if (params == nil) {
        requestParams = [[NSMutableDictionary alloc] init];
    } else {
        requestParams = [params mutableCopy];
    }
    [requestParams setObject:[UIDevice currentDevice].imei forKey:@"imei"];
    [requestParams setObject:[UIDevice currentDevice].imsi forKey:@"imsi"];
    [requestParams setObject:[[NSDate currentDateString] urlEncode] forKey:@"submittime"];
    if (![requestParams.allKeys containsObject:@"mt_token"]) {
        [requestParams setObject:[UIDevice currentDevice].mt_token forKey:@"mt_token"];//token
    }
    if (![requestParams.allKeys containsObject:@"dwzzb_token"]&&![uri containsString:@"DWGL_APP"]&&[uri containsString:@"DWGL"]) {
        [requestParams setObject:isnull([[MTGlobalInfo sharedInstance] getAttribute:@"dwzzb_token"]) forKey:@"dwzzb_token"];//token
    }
    
    //特殊参数(在各自项目内使用category复写)
    [self addSpecialparams:requestParams];
    
    
    
    HttpCommonOperation *operation = [[HttpCommonOperation alloc] initWithURL:urlStr params:requestParams isDataImage:isImage];
    [operation setResponseNSDataHandler:^(NSData *response)  {
        
        //======================================================
        NSString * isNotSave = requestParams[@"isNotSave"];
        if (nil == isNotSave) {
            [self updateSessionID];
        }
        //======================================================
        
        if (response != nil) {
            handler(response);
            
        } else {
            handler(response);
            
            if (loadingHint) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"网络连接超时,请检查网络是否可用", nil)];
                });
                
            }
        }
    }];
    
    //    [SpeedTestHistory MR_truncateAll];
    
    [_opreationQueue addOperation:operation];
    
    DLog(@"[URLStr] >>> %@", urlStr);
    DLog(@"[Params] >>> %@", [requestParams JSONString]);
    
}



#pragma mark - 没有Zip加密


- (void)requestNoZipWithURL:(NSString *)uri Params:(NSDictionary *)params Handler:(MessageHandler)handler {
    [self requestNoZipWithURL:uri Params:params LoadingHint:nil DoneHint:nil Handler:handler];
}

- (void)requestNoZipWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint Handler:(MessageHandler)handler {
    [self requestNoZipWithURL:uri Params:params LoadingHint:loadingHint DoneHint:nil Handler:handler];
}

- (void)requestNoZipWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler {
    [self requestNoZipWithURL:uri Params:params LoadingHint:loadingHint DoneHint:doneHint customSuccess:NO Handler:handler];
}

- (void)requestNoZipWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint customSuccess:(BOOL)customSuccess Handler:(MessageHandler)handler{
    
    if (loadingHint) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:loadingHint maskType:SVProgressHUDMaskTypeBlack];
        });
        
    }
    
    NSString *urlStr = nil;
    if ([uri hasPrefix:@"http://"] || [uri hasPrefix:@"https://"]) {
        urlStr=uri;
    }
    else
    {
        NSDictionary *dic = [NSBundle mainBundle].infoDictionary;
        BOOL useHttps = [[dic objectForKey:@"USEHTTPS"]boolValue];
        if(useHttps) {
            urlStr= [NSString stringWithFormat:@"https://%@%@", self.serverAddress, uri];
        } else {
            urlStr= [NSString stringWithFormat:@"http://%@%@", self.serverAddress, uri];
        }
    }
    
    //    NSURL *URL = [NSURL URLWithString:urlStr];
    //
    NSMutableDictionary *requestParams = nil;
    if (params == nil) {
        requestParams = [[NSMutableDictionary alloc] init];
    } else {
        requestParams = [params mutableCopy];
    }
    
    [requestParams setObject:[UIDevice currentDevice].imei forKey:@"imei"];
    [requestParams setObject:[UIDevice currentDevice].imsi forKey:@"imsi"];
    [requestParams setObject:[[NSDate currentDateString] urlEncode] forKey:@"submittime"];
    if (![requestParams.allKeys containsObject:@"mt_token"]) {
        [requestParams setObject:[UIDevice currentDevice].mt_token forKey:@"mt_token"];//token
    }
    if (![requestParams.allKeys containsObject:@"dwzzb_token"]&&![uri containsString:@"DWGL_APP"]&&[uri containsString:@"DWGL"]) {
        [requestParams setObject:isnull([[MTGlobalInfo sharedInstance] getAttribute:@"dwzzb_token"]) forKey:@"dwzzb_token"];//token
    }
    
    HttpCommonOperation *operation = [[HttpCommonOperation alloc] initNoZipWithURL:urlStr params:requestParams];
    [operation setTimeout:_timeout];
    [operation setResponseHandler: ^(NSDictionary *response) {
        _timeout=TIMEOUT;
        if (response != nil) {
            
            DLog(@"[Response] >>> %@",[response JSONString]);
            
            
            
            [self handleMTToken:response];//mt_token
            
            
            if (!customSuccess) {
                int retValue = [[response objectForKey:@"success"] intValue];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (retValue == HTTP_STATE_CALL_SUCCESS) {
                        if (doneHint) {
                            [SVProgressHUD showSuccessWithStatus:doneHint];
                        } else if(loadingHint){
                            [SVProgressHUD dismiss];
                        }
                    } else {
                        //                   [SVProgressHUD dismiss];
                        [SVProgressHUD showErrorWithStatus:[response objectForKey:@"result"]];
                        
                    }
                });
            }
            
            handler(response);
        } else {
            if (loadingHint) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"网络连接超时,请检查网络是否可用", nil)];
                });
            }
            handler(response);
            
        }
    }];
    
    //    [SpeedTestHistory MR_truncateAll];
    
    [_opreationQueue addOperation:operation];
    
    DLog(@"[URLStr] >>> %@", urlStr);
    DLog(@"[Params] >>> %@", [requestParams JSONString]);
    
}



#pragma mark - 同步获取数据
/**
 *  同步获取数据
 *
 */
- (NSDictionary *)respondSyncFromURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint{
    if (loadingHint) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:loadingHint];
        });
    }
    
//    NSString *urlStr = [NSString stringWithFormat:@"http://%@%@", self.serverAddress, uri];
    
    
    //4
    BOOL useHttps = [[[NSBundle mainBundle].infoDictionary objectForKey:@"USEHTTPS"] boolValue];
    NSString *urlStr = nil;
    if ([uri hasPrefix:@"http://"] || [uri hasPrefix:@"https://"]) {
        urlStr=uri;
    }
    else
    {
        NSDictionary *dic = [NSBundle mainBundle].infoDictionary;
        if(useHttps) {
            urlStr= [NSString stringWithFormat:@"https://%@%@", self.serverAddress, uri];
        } else {
            urlStr= [NSString stringWithFormat:@"http://%@%@", self.serverAddress, uri];
        }
    }
    
    NSMutableDictionary *requestParams = nil;
    if (params == nil) {
        requestParams = [[NSMutableDictionary alloc] init];
    } else {
        requestParams = [params mutableCopy];
    }
    [requestParams setObject:[UIDevice currentDevice].imei forKey:@"imei"];
    [requestParams setObject:[UIDevice currentDevice].imsi forKey:@"imsi"];
    
    //特殊参数(在各自项目内使用category复写)
    [self addSpecialparams:requestParams];
    
    //初始化http请求
    NSMutableString *paramsStr = nil;
    if (requestParams != nil && [requestParams count] > 0) {
        NSMutableString *tempStr = [NSMutableString string];
        NSArray *keys = [requestParams allKeys];
        for (int i = 0; i < [keys count]; i++) {
            [tempStr appendString:[NSString stringWithFormat:@"%@=%@&", [keys objectAtIndex:i], [requestParams objectForKey:[keys objectAtIndex:i]]]];
        }
        
        paramsStr = [NSMutableString stringWithString:[tempStr substringToIndex:[tempStr length] - 1]];
    }
    
    
    //初始化http请求
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    [request setURL:[NSURL URLWithString:urlStr]];
    
    [request setHTTPMethod:@"POST"];
    
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setValue:@"utf-8" forHTTPHeaderField:@"Accept-Language"];
    [request setTimeoutInterval:30.0];
    
    if (paramsStr != nil) {
        [request setHTTPBody:[paramsStr dataUsingEncoding:NSUTF8StringEncoding]];
    }
    //同步返回请求，并获得返回数据
    NSHTTPURLResponse *urlResponse = nil;
//    NSError *error = [[NSError alloc] init];
    
    DLog(@"[URLStr] >>> %@", urlStr);
    DLog(@"[Params] >>> %@", [requestParams JSONString]);
    
    
//    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:nil];
    
    //请求返回状态，如有中文无法发送请求，并且stausCode 值为 0
    
    DLog(@"response code:%ld",(long)[urlResponse statusCode]);
    
    if([urlResponse statusCode] >= 200 && [urlResponse statusCode] <300){
        NSDictionary *jsonObject = [responseData objectFromJSONData];
        if (jsonObject == nil) {
            jsonObject = [[self dataDecode:responseData] objectFromJSONString];
        }
        
        DLog(@"[Response] >>> %@", [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
        
        if (doneHint) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showSuccessWithStatus:doneHint];
            });
        } else if (loadingHint) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });
        }
        return [responseData objectFromJSONData];
        
    }else{
//        NSLog(@"Error: %@", error);
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"网络连接超时,请检查网络是否可用", nil)];
        });
        return nil;
    }
    
    
}

/**
 *  同步获取数据
 *
 */
- (NSData *)respondSyncDataFromURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint{
    if (loadingHint) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:loadingHint];
        });
    }
    
    //5
    BOOL useHttps = [[[NSBundle mainBundle].infoDictionary objectForKey:@"USEHTTPS"] boolValue];
    NSString *urlStr = nil;
    if ([uri hasPrefix:@"http://"] || [uri hasPrefix:@"https://"]) {
        urlStr=uri;
    }
    else
    {
        NSDictionary *dic = [NSBundle mainBundle].infoDictionary;
        if(useHttps) {
            urlStr= [NSString stringWithFormat:@"https://%@%@", self.serverAddress, uri];
        } else {
            urlStr= [NSString stringWithFormat:@"http://%@%@", self.serverAddress, uri];
        }
    }
    
    NSMutableDictionary *requestParams = nil;
    if (params == nil) {
        requestParams = [[NSMutableDictionary alloc] init];
    } else {
        requestParams = [params mutableCopy];
    }
    [requestParams setObject:[UIDevice currentDevice].imei forKey:@"imei"];
    [requestParams setObject:[UIDevice currentDevice].imsi forKey:@"imsi"];
    
    //特殊参数(在各自项目内使用category复写)
    [self addSpecialparams:requestParams];
    
    //初始化http请求
    NSMutableString *paramsStr = nil;
    if (requestParams != nil && [requestParams count] > 0) {
        NSMutableString *tempStr = [NSMutableString string];
        NSArray *keys = [requestParams allKeys];
        for (int i = 0; i < [keys count]; i++) {
            [tempStr appendString:[NSString stringWithFormat:@"%@=%@&", [keys objectAtIndex:i], [requestParams objectForKey:[keys objectAtIndex:i]]]];
        }
        
        paramsStr = [NSMutableString stringWithString:[tempStr substringToIndex:[tempStr length] - 1]];
    }
    
    
    //初始化http请求
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    
    [request setURL:[NSURL URLWithString:urlStr]];
    
    [request setHTTPMethod:@"POST"];
    
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setValue:@"utf-8" forHTTPHeaderField:@"Accept-Language"];
    [request setTimeoutInterval:30.0];
    
    if (paramsStr != nil) {
        [request setHTTPBody:[paramsStr dataUsingEncoding:NSUTF8StringEncoding]];
    }
    //同步返回请求，并获得返回数据
    NSHTTPURLResponse *urlResponse = nil;
    NSError *error = [[NSError alloc] init];
    
    DLog(@"[URLStr] >>> %@", urlStr);
    DLog(@"[Params] >>> %@", [requestParams JSONString]);
    
    
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];
    
    //请求返回状态，如有中文无法发送请求，并且stausCode 值为 0
    
    DLog(@"response code:%ld",(long)[urlResponse statusCode]);
    
    if([urlResponse statusCode] >= 200 && [urlResponse statusCode] <300){
        
        DLog(@"[Response] >>> %@", [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
        
        if (doneHint) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showSuccessWithStatus:doneHint];
            });
        } else if (loadingHint) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });
        }
        return responseData;
        
    }else{
        NSLog(@"Error: %@", error);
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"网络连接超时,请检查网络是否可用", nil)];
        });
        return nil;
    }
    
    
}

-(NSData *)syncGetRequestWithURL:(NSString *)uri params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint{
    if (loadingHint) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showWithStatus:loadingHint];
        });
    }
    
    //6
    BOOL useHttps = [[[NSBundle mainBundle].infoDictionary objectForKey:@"USEHTTPS"] boolValue];
    NSString *urlStr = nil;
    if ([uri hasPrefix:@"http://"] || [uri hasPrefix:@"https://"]) {
        urlStr=uri;
    }
    else
    {
        NSDictionary *dic = [NSBundle mainBundle].infoDictionary;
        if(useHttps) {
            urlStr= [NSString stringWithFormat:@"https://%@%@", self.serverAddress, uri];
        } else {
            urlStr= [NSString stringWithFormat:@"http://%@%@", self.serverAddress, uri];
        }
    }
    
    //NSString *urlStr = [NSString stringWithFormat:@"http://%@%@", self.serverAddress, uri];
    
    NSMutableDictionary *requestParams = nil;
    if (params == nil) {
        requestParams = [[NSMutableDictionary alloc] init];
    } else {
        requestParams = [params mutableCopy];
    }
    [requestParams setObject:[UIDevice currentDevice].imei forKey:@"imei"];
    [requestParams setObject:[UIDevice currentDevice].imsi forKey:@"imsi"];
    
    //特殊参数(在各自项目内使用category复写)
    [self addSpecialparams:requestParams];
    
    NSMutableString* uriString = [NSMutableString string];
    for (NSString* key in requestParams.allKeys) {
        NSString* value = [NSString stringWithFormat:@"%@",[requestParams valueForKey:key]];
        value = [value urlEncode];
        [uriString appendFormat:@"%@=%@&",key,value];
    }
    if (uriString.length > 0) {
        [uriString deleteCharactersInRange:NSMakeRange(uriString.length-1, 1)];
    }
    
    NSURL* URL = [NSURL URLWithString:[NSString stringWithFormat:@"%@?%@",urlStr,uriString]];
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    request.URL = URL;
    [request setHTTPMethod:@"GET"];
    [request setTimeoutInterval:30.0];
    
    NSHTTPURLResponse* response = nil;
    NSError* error = nil;
    NSData* data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if([response statusCode] >= 200 && [response statusCode] <300){
        
        if (doneHint) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showSuccessWithStatus:doneHint];
            });
        } else if (loadingHint) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];
            });
        }
        return data;
        
    }else{
        dispatch_async(dispatch_get_main_queue(), ^{
            [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"网络连接超时,请检查网络是否可用", nil)];
        });
        return nil;
    
    }
}


- (NSString *)dataDecode:(NSData *)data {
    if (data == nil) {
        return nil;
    }
    
    Byte *byte = (Byte *)[data bytes];
    for (int i = 0; i < [data length]; i++) {
        *byte = *byte - 8;
        byte++;
    }
    
    return [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];
}

#pragma mark - getter
- (NSMutableArray *)cerFiles {
    
    if(nil == _cerFiles) {
        [staticFileArray1 removeAllObjects];
        NSString *path = [[NSBundle mainBundle]bundlePath];
        [staticFileArray1 removeAllObjects];
        
        _cerFiles = [self getCerFiles:path];
    }
    
    return _cerFiles;
}

#pragma mark - privated methods
- (void)backGroundReloginHandler:(void(^)(BOOL))reloginHandler{
    if (_urlAndParams == nil) {
        [SVProgressHUD dismiss];
        reloginHandler(NO);//无登录参数原请求响应nil
        return;
    }
    
    if (_willDealBlocks == nil)
        _willDealBlocks = [NSMutableArray new];
    if (![_willDealBlocks containsObject:reloginHandler])
        [_willDealBlocks addObject:reloginHandler];//记录待处理代码
    
    NSInteger limitTimeInterval         = 5*60;
    NSInteger notTimeOutTimeInterval    = 25*60;//预估
    
#ifdef DEBUG
    limitTimeInterval = 60;
    notTimeOutTimeInterval = 90;
#endif
    
    if (self.isRelogining) {
        //正在进行重登录
        return;
    }else if (_relogionSuccessDate&&([[NSDate date] timeIntervalSinceDate:_relogionSuccessDate] < notTimeOutTimeInterval)) {
        //上一次成功重登录时间小于25分钟直接处理
        if ([_willDealBlocks containsObject:reloginHandler])
            [_willDealBlocks removeObject:reloginHandler];
        reloginHandler(NO);
        return;
    }else if (_lastRelogionDate&&([[NSDate date] timeIntervalSinceDate:_lastRelogionDate] < limitTimeInterval)) {
        //两次重登录间隔不能小于5分钟
        if ([_willDealBlocks containsObject:reloginHandler])
            [_willDealBlocks removeObject:reloginHandler];
        reloginHandler(NO);
        return;
    }
    
    //==============================================================
    //自定义下一次的Cookie
    
    //    NSString * tempCookie= [[MTGlobalInfo sharedInstance] getAttribute:@"TempCookie"];
    //    if (nil != tempCookie ) {
    //        [[MTGlobalInfo sharedInstance] putAttribute:@"CustomCookie" value:tempCookie];
    //    }
    //更新sessionID(放在此处是为了第一适配次超时时的异步请求)
    [self updateSessionID];
    //============================================================
    
    
    _lastRelogionDate = [NSDate date];
    self.isRelogining = YES;
    
    NSString * url = _urlAndParams[@"url"];
    NSDictionary *argvDict = _urlAndParams[@"params"];
    
    [self requestWithURL:url Params:argvDict LoadingHint:nil DoneHint:nil Handler:^(NSDictionary *response) {
        self.isRelogining = NO;
        [self handleMTToken:response];//mt_token
        
        if ([[response valueForKey:@"success"] integerValue] == 1) {
            _relogionSuccessDate = [NSDate date];
            for (void(^block)(BOOL) in _willDealBlocks)
                block(YES);
            [_willDealBlocks removeAllObjects];
        }else{
            for (void(^block)(BOOL) in _willDealBlocks)
                block(NO);
            [_willDealBlocks removeAllObjects];
            [SVProgressHUD dismiss];
        }
    } timeOutHandler:nil isZip:NO customSuccess:NO];
}

- (void)updateSessionID {
    if (_lastSession == nil) {
        return;
    }
    NSHTTPCookie * lastSessionID = _lastSession;
    NSMutableArray * tempArr = [[NSMutableArray alloc]initWithArray:self.cookies];
    NSArray *arrM = [tempArr copy];
    for (NSHTTPCookie * item in arrM) {
        if ([item.name isEqualToString:@"JSESSIONID"]) {
            [tempArr removeObject:item];
        }
    }
    
    [tempArr addObject:lastSessionID];
    self.cookies = tempArr;
}

static NSMutableArray * staticFileArray1;//由于是递归方法中共用了同一个数组，所以设为静态变量，在使用前记得置NULL
- (NSMutableArray*)getCerFiles:(NSString *)path{
    // 1.判断文件还是目录
    NSFileManager * fileManger = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isExist = [fileManger fileExistsAtPath:path isDirectory:&isDir];
    if (isExist) {
        // 2. 判断是不是目录
        if (isDir) {
            NSArray * dirArray = [fileManger contentsOfDirectoryAtPath:path error:nil];
            NSString * subPath = nil;
            for (NSString * str in dirArray) {
                subPath  = [path stringByAppendingPathComponent:str];
                BOOL issubDir = NO;
                [fileManger fileExistsAtPath:subPath isDirectory:&issubDir];
                [self getCerFiles:subPath];
            }
            
        }else{
            
            if(nil == staticFileArray1) {
                staticFileArray1 = [NSMutableArray new];
            }
            if([path rangeOfString:@".cer"].location != NSNotFound) {
                DLog(@"%@",path);
                [staticFileArray1 addObject:path];
            }
        }
    }else{
        DLog(@"你打印的是目录或者不存在");
        return nil;
    }
    return staticFileArray1;
}

#pragma mark - 附加参数
- (void)addSpecialparams:(NSMutableDictionary *)requestParams {
    //category
}

#pragma mark - mt_token
- (void)handleMTToken:(NSDictionary *)response {
    NSString * mt_token = response[@"mt_token"];
    if (mt_token&&[mt_token isKindOfClass:[NSString class]]) {
        [[NSUserDefaults standardUserDefaults] setObject:mt_token forKey:@"mt_token"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}


#pragma mark - 网络请求实现部分
#pragma mark -- 全自定义 已废弃, 请参照分类中的实现
/**
 *  全自定义
 *
 */
- (void)requestWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler timeOutHandler:(MessageTimeOutHandler)timeOutHandler isZip:(BOOL)isZip customSuccess:(BOOL)customSuccess {
    NSLog(@"2_____________________________________________________");
    //离线回调=====================
    NSDictionary * offlineResponse = [[MTOfflineManager shareManager] recordUrl:uri andParam:params];
    if (offlineResponse) {
        if ([offlineResponse isEqualToDictionary:@{}]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD showErrorWithStatus:@"暂无离线数据"];
            });
            handler(nil);
            return;
        }
        handler(offlineResponse);
        return;
    }
    //============================
    
    if (loadingHint) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"3_____________________________________________________");
            [SVProgressHUD showWithStatus:loadingHint maskType:SVProgressHUDMaskTypeBlack];
        });
        
    }
    
    //3
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
    
    
    NSMutableDictionary *requestParams = nil;
    if (params == nil) {
        requestParams = [[NSMutableDictionary alloc] init];
    } else {
        requestParams = [params mutableCopy];
    }
    
    // 添加额外参数
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
    if (![requestParams.allKeys containsObject:@"dwzzb_token"]&&![uri containsString:@"DWGL_APP"]&&[uri containsString:@"DWGL"]) {
        [requestParams setObject:isnull([[MTGlobalInfo sharedInstance] getAttribute:@"dwzzb_token"]) forKey:@"dwzzb_token"];//token
    }
    
    if (![requestParams.allKeys containsObject:@"logincode"]) {
        NSString * logincode = [[NSUserDefaults standardUserDefaults] objectForKey:@"username"];
        if (logincode) {
            //用于检验同时间仅有一台手机在使用账号
            [requestParams setObject:logincode forKey:@"logincode"];
        }
    }
    
    
    //特殊参数(在各自项目内使用category复写)
    [self addSpecialparams:requestParams];
    
    NSString *jsonStr = [urlStr copy];
    jsonStr = [jsonStr stringByAppendingString:@"\n"];
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:requestParams options:NSJSONWritingPrettyPrinted error:nil];
    jsonStr = [jsonStr stringByAppendingString:[[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding]];
    [MTFileManager recordNetRequest:jsonStr fileBody:MTFileBody_Begin];
    
    
    HttpCommonOperation *operation = [[HttpCommonOperation alloc] initWithURL:urlStr params:requestParams isDataZip:isZip];
    [operation setTimeout:_timeout];
    [operation setResponseHandler: ^(NSDictionary *response) {
        _timeout = TIMEOUT;
        if (response != nil) {
            
            DLog(@"[Response] >>> %@",[response JSONString]);
            [MTFileManager recordNetRequest:[response JSONString] fileBody:MTFileBody_Center];
            
            [self handleMTToken:response];//mt_token
            
            
            int retValue = [[response objectForKey:@"success"] intValue];
            dispatch_async(dispatch_get_main_queue(), ^{
                if (customSuccess) {
                    NSLog(@"4_____________________________________________________");
                    //自定义处理过程不做任何处理
                    if(loadingHint){
                        NSLog(@"5_____________________________________________________");
                        [SVProgressHUD dismiss];
                    }
                }else if (retValue == HTTP_STATE_CALL_SUCCESS) {
                    if (doneHint) {
                        NSLog(@"6_____________________________________________________");
                        [SVProgressHUD showSuccessWithStatus:doneHint];
                    } else if(loadingHint){
                        NSLog(@"7_____________________________________________________");
                        [SVProgressHUD dismiss];
                    }
                    NSLog(@"8_____________________________________________________");
                    //记录回调
                    [[MTOfflineManager shareManager] saveResponse:response withUrl:uri andParam:params];
                    
                }else if (retValue == HTTP_STATE_SESSION_INVALID){
                    //超时可重新登陆
                    if (timeOutHandler) {
//                        [self backGroundReloginTimeOutHandler:timeOutHandler Handler:handler];
                        void(^reloginHandler)(BOOL)  = ^(BOOL reloginAcceptedAndSuccess){
                            NSDictionary* reloginSuccessResp = @{@"success":@(HTTP_STATE_SESSION_INVALID),
                                                                 @"result":@"长时间未操作，已重新登录成功，请重新操作"};
                            handler(reloginAcceptedAndSuccess ? reloginSuccessResp : response);
                        };
                        [self backGroundReloginHandler:reloginHandler];
                    }else{
                        NSString *res = [response objectForKey:@"result"];
                        if (![res isEqualToString:@""]) {
                            [SVProgressHUD showErrorWithStatus:NSLocalizedString(res, nil)];
                        }
                    }
                }else if (retValue == HTTP_STATE_WAIT_REPEAT){
                    [[NSNotificationCenter defaultCenter]postNotificationName:@"logoutAction" object:nil userInfo:nil];
                    [SVProgressHUD dismiss];
                    //截断
                    return;
                }else {
                    //[SVProgressHUD dismiss];
                    NSString *res = [response objectForKey:@"result"];
                    if (![res isEqualToString:@""]) {
                        if ([urlStr containsString:@"LoginOut.mt"]) {
                            
                        } else {
//                            [SVProgressHUD showErrorWithStatus:NSLocalizedString(res, nil)];
                        }
                        
                    }
                    else {
                        [SVProgressHUD showErrorWithStatus:@"后台返回错误，错误信息为空"];
                    }
                }
            });
            
            if (retValue == HTTP_STATE_SESSION_INVALID&&timeOutHandler) {
                return;
            }
            
            //==============================================================
            //自定义下一次的Cookie
            
            NSString * isNotSave = requestParams[@"isNotSave"];
            //            NSString * tempCookie= [[MTGlobalInfo sharedInstance] getAttribute:@"TempCookie"];
            //TODO
            
            if (nil == isNotSave) {
                //                [[MTGlobalInfo sharedInstance] putAttribute:@"CustomCookie" value:tempCookie];
                [self updateSessionID];
            }
            //============================================================
            
            handler(response);
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
                [SVProgressHUD dismiss];//有可能在请求外自己添加了HUD
            });
            if (loadingHint) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"网络连接超时,请检查网络是否可用", nil)];
                });
            }
            handler(response);
        }
        
        [MTFileManager recordNetRequest:urlStr fileBody:MTFileBody_End];
    }];
    
    //    [SpeedTestHistory MR_truncateAll];
    
    [_opreationQueue addOperation:operation];
    
    NSLog(@"9_____________________________________________________");
    DLog(@"[URLStr] >>> %@", urlStr);
    DLog(@"[Params] >>> %@", [requestParams JSONString]);
    
}

/**
 *  自定义加载和完成提示 gzip
 *
 *  这里的方法实现其实跟全自定义里面的是一样的，故应舍弃这里的实现部分，使用全自定义簇方法
 */
/*
 - (void)requestMTZipWithURL:(NSString *)uri Params:(NSDictionary *)params LoadingHint:(NSString *)loadingHint DoneHint:(NSString *)doneHint Handler:(MessageHandler)handler {
 if (loadingHint) {
 dispatch_async(dispatch_get_main_queue(), ^{
 [SVProgressHUD showWithStatus:loadingHint maskType:SVProgressHUDMaskTypeBlack];
 });
 
 }
 
 NSString *urlStr = nil;
 if ([uri hasPrefix:@"http://"] || [uri hasPrefix:@"https://"]) {
 urlStr=uri;
 }
 else
 {
 NSDictionary *dic = [NSBundle mainBundle].infoDictionary;
 BOOL useHttps = [[dic objectForKey:@"USEHTTPS"]boolValue];
 if(useHttps) {
 urlStr= [NSString stringWithFormat:@"https://%@%@", self.serverAddress, uri];
 } else {
 urlStr= [NSString stringWithFormat:@"http://%@%@", self.serverAddress, uri];
 }
 }
 
 //    NSURL *URL = [NSURL URLWithString:urlStr];
 //
 NSMutableDictionary *requestParams = nil;
 if (params == nil) {
 requestParams = [[NSMutableDictionary alloc] init];
 } else {
 requestParams = [params mutableCopy];
 }
 
 [requestParams setObject:[UIDevice currentDevice].imei forKey:@"imei"];
 [requestParams setObject:[UIDevice currentDevice].imsi forKey:@"imsi"];
 [requestParams setObject:[[NSDate currentDateString] urlEncode] forKey:@"submittime"];
 if (![requestParams.allKeys containsObject:@"mt_token"]) {
 [requestParams setObject:[UIDevice currentDevice].mt_token forKey:@"mt_token"];//token
 }
 if (![requestParams.allKeys containsObject:@"dwzzb_token"]&&![uri containsString:@"DWGL_APP"]&&[uri containsString:@"DWGL"]) {
 [requestParams setObject:isnull([[MTGlobalInfo sharedInstance] getAttribute:@"dwzzb_token"]) forKey:@"dwzzb_token"];//token
 }
 
 HttpCommonOperation *operation = [[HttpCommonOperation alloc] initMTDataZipWithURL:urlStr params:requestParams];
 [operation setTimeout:_timeout];
 [operation setResponseHandler: ^(NSDictionary *response) {
 _timeout=TIMEOUT;
 if (response != nil) {
 
 DLog(@"[Response] >>> %@",[response JSONString]);
 
 
 
 [self handleMTToken:response];//mt_token
 
 
 int retValue = [[response objectForKey:@"success"] intValue];
 dispatch_async(dispatch_get_main_queue(), ^{
 if (retValue == HTTP_STATE_CALL_SUCCESS) {
 if (doneHint) {
 [SVProgressHUD showSuccessWithStatus:doneHint];
 } else if(loadingHint){
 [SVProgressHUD dismiss];
 }
 } else {
 //                   [SVProgressHUD dismiss];
 [SVProgressHUD showErrorWithStatus:[response objectForKey:@"result"]];
 
 }
 });
 
 handler(response);
 } else {
 if (loadingHint) {
 dispatch_async(dispatch_get_main_queue(), ^{
 [SVProgressHUD showErrorWithStatus:NSLocalizedString(@"网络连接超时,请检查网络是否可用", nil)];
 });
 }
 handler(response);
 
 }
 }];
 
 //    [SpeedTestHistory MR_truncateAll];
 
 [_opreationQueue addOperation:operation];
 
 DLog(@"[URLStr] >>> %@", urlStr);
 DLog(@"[Params] >>> %@", [requestParams JSONString]);
 
 }
 */

@end
