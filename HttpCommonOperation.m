//
//  HttpCommonOperation.m
//  NetRecord_BJ
//
//  Created by adt on 13-12-5.
//  Copyright (c) 2013年 MasterCom. All rights reserved.
//

#import "HttpCommonOperation.h"
//#define TIMEOUT 120.0
@interface HttpCommonOperation () <NSURLSessionDelegate> {
    ResponseHandler _handler;
    ResponseNSDataHandler _nsDataHandler;
    NSMutableData *_result;
    BOOL _isZip;
    BOOL _isMtZip;
    BOOL _isImage;
    NSInteger _timeout;
   
}

@property (nonatomic, strong) NSMutableArray *cerFiles;

@end

@implementation HttpCommonOperation


- (id)initWithURL:(NSString *)url params:(NSDictionary *)params {
    return [self initWithURL:url params:params isDataZip:NO];
}

- (id)initWithURL:(NSString *)url params:(NSDictionary *)params isDataZip:(BOOL)isZip {
    self = [super init];
    if (self) {
        _url = [[NSString alloc] initWithString:url];
        _params = [[NSDictionary alloc] initWithDictionary:params];
        _result = [[NSMutableData alloc] init];
        _isZip = isZip;
#if MTZIP
        _isMtZip=YES;
#endif
    }
    return self;
}
- (id)initMTDataZipWithURL:(NSString *)url params:(NSDictionary *)params
{
    self = [super init];
    if (self) {
        _url = [[NSString alloc] initWithString:url];
        _params = [[NSDictionary alloc] initWithDictionary:params];
        _result = [[NSMutableData alloc] init];
        _isMtZip=YES;
        _isZip=NO;
        
    }
    return self;
}
- (id)initNoZipWithURL:(NSString *)url params:(NSDictionary *)params
{
    self = [super init];
    if (self) {
        _url = [[NSString alloc] initWithString:url];
        _params = [[NSDictionary alloc] initWithDictionary:params];
        _result = [[NSMutableData alloc] init];
        _isMtZip=NO;
        _isZip=NO;
        
    }
    return self;
}
- (id)initWithURL:(NSString *)url params:(NSDictionary *)params  isDataImage:(BOOL)isImage {
    self = [super init];
    if (self) {
        _url = [[NSString alloc] initWithString:url];
        _params = [[NSDictionary alloc] initWithDictionary:params];
        _result = [[NSMutableData alloc] init];
        _isImage=isImage;
#if MTZIP
        _isMtZip=YES;
#endif
    }
    return self;
}
- (void)setResponseHandler:(ResponseHandler)handler {
    _handler = handler;
}
-(void) setResponseNSDataHandler:(ResponseNSDataHandler)handler
{
    _nsDataHandler=handler;
}
- (void)setTimeout:(NSInteger) timeout
{
    _timeout=timeout;
}
- (void)start {

    if ([self isCancelled]) {
        return;
    }
    if (_timeout<1) {
        _timeout=120;
    }
    NSArray *urlArray = [_url componentsSeparatedByString:@"?"];
    
    NSString *pureUrl = urlArray[0];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:pureUrl]
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:10.0];
    
    
    NSMutableString *paramsStr = nil;
    if ((_params != nil && [_params count] > 0) || [urlArray count]>1) {
        NSMutableString *tempStr = [NSMutableString string];
        if([urlArray count]>1){
            [tempStr appendString:urlArray[1]];
            if([urlArray[1] length]>0 && ![urlArray[1] hasSuffix:@"&"]){
                [tempStr appendString:@"&"];
            }
        }
        NSArray *keys = [_params allKeys];
        for (int i = 0; i < [keys count]; i++) {
            NSString* key = [keys objectAtIndex:i];
            NSString* value = [NSString stringWithFormat:@"%@",[_params valueForKey:key]];
            [tempStr appendString:[NSString stringWithFormat:@"%@=%@&", key, value]];
        }   
        
        paramsStr = [NSMutableString stringWithString:[tempStr substringToIndex:[tempStr length] - 1]];
    }
    
    //=================================================================================
    
    NSMutableArray  * cookies       = [HttpCommon sharedInstance].cookies;
    NSDictionary    * cookieDict    = [NSHTTPCookie requestHeaderFieldsWithCookies:cookies];
    
    
//    NSMutableString *cookieString = [[NSMutableString alloc] init];
//    [cookieString appendFormat:@"userid=%@;", @"xxxx"];
//    [cookieString appendFormat:@" sessionid=%@;", @"xxxx"];
//    [cookieString appendFormat:@" nickname=%@;", @"xxxx"];
    
//    NSString *cookie = [[MTGlobalInfo sharedInstance] getAttribute:@"CustomCookie"];
//    if (nil == cookie || cookie.length == 0) {
//        [request setValue:@"" forHTTPHeaderField:@"Cookie"];
//        DLog(@"发送的cookie为空");
//    }
//    else {
//        [request setValue:cookie forHTTPHeaderField:@"Cookie"];
//        DLog(@"发送的cookie:%@",cookie);
//    }

    if (cookies.count == 0) {
        [request setValue:@"" forHTTPHeaderField:@"Cookie"];
        DLog(@"发送的cookie为空");
    }
    else {
        NSMutableString * cookiesStr = [[NSMutableString alloc]initWithString:@""];
        for (NSInteger i = 0; i < cookies.count; i ++) {
            NSHTTPCookie * cookie = cookies[i];
            [cookiesStr appendFormat:@"%@%@",cookiesStr.length?@" ":@"",[NSString stringWithFormat:@"%@=%@;",cookie.name,cookie.value]];
        }
        [request setValue:cookiesStr forHTTPHeaderField:@"Cookie"];
//        request.allHTTPHeaderFields = cookieDict;
        DLog(@"发送的cookie:%@",cookieDict);
    }
    
    //=================================================================================
    
    [request setHTTPMethod:@"POST"];
    [request setValue:@"gzip" forHTTPHeaderField:@"Accept-Encoding"];
    [request setValue:@"utf-8" forHTTPHeaderField:@"Accept-Language"];
    [request setTimeoutInterval:_timeout];
    
    //DLog(@"*******************\n%@******************\n",paramsStr);
    if (paramsStr != nil) {
        if (_isZip) {
            [request setHTTPBody:[[paramsStr dataUsingEncoding:NSUTF8StringEncoding] gzippedData]];
        }
        else if(_isMtZip)
        {
            NSData* paramsStrData = [paramsStr dataUsingEncoding:NSUTF8StringEncoding];
            NSData* data= [self dataEncode:paramsStrData];
            
            [request setValue:@"application/mtzip" forHTTPHeaderField:@"Content-Type"];
            [request setHTTPBody:[data gzippedData]];
        }else {
            [request setHTTPBody:[paramsStr dataUsingEncoding:NSUTF8StringEncoding]];
        }
    }
    
    
    NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:self];
    [connection start];
    
    [[NSRunLoop currentRunLoop] run];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    NSDictionary *files = ((NSHTTPURLResponse *)response).allHeaderFields;
    NSString *rtCookie = files[@"Set-Cookie"];
    NSString *isNotSave = _params[@"isNotSave"];
    DLog(@"返回的cookie:%@",rtCookie);
    if (nil != rtCookie &&isNotSave == nil) {
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
        
        
        //        for (NSHTTPCookie * cookie in cookies) {
        //            NSString * name = cookie.name;
        //            for (NSInteger i = 0; i < tempCookie.count; i ++) {
        //                NSHTTPCookie * tcookie = tempCookie[i];
        //                NSString * tname = tcookie.name;
        //                if ([name isEqualToString:tname]) {
        //                    [tempCookie replaceObjectAtIndex:i withObject:cookie];
        //                }
        //            }
        //        }
        //        [NSHTTPCookie requestHeaderFieldsWithCookies:<#(nonnull NSArray<NSHTTPCookie *> *)#>]
        //        NSString * string = [NSHTTPCookie ]
        
        //        [[MTGlobalInfo sharedInstance] putAttribute:@"TempCookie" value:rtCookie];
    }
    
    //    if (nil == isNotSave && nil != rtCookie &&(![MTGlobalInfo sharedInstance].isRelogining)||  )) {
    //        //[[MTGlobalInfo sharedInstance] putAttribute:@"CustomCookie" value:rtCookie];
    //        [[MTGlobalInfo sharedInstance] putAttribute:@"relo" value:rtCookie];
    //    }
}



- (BOOL)isFinished {
    return YES;
}



- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {

    if ([[[challenge protectionSpace] authenticationMethod] isEqualToString: NSURLAuthenticationMethodServerTrust]) {
        do
        {
            SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
            NSCAssert(serverTrust != nil, @"serverTrust is nil");
            if(nil == serverTrust)
                break; /* failed */
           
            /**
             *  从NSBundle中导入多张CA证书（Certification Authority，支持SSL证书以及自签名的CA
             */
  
            NSMutableArray *caArray;
            for (NSString *cerPath in self.cerFiles) {
                NSData* caCert = [NSData dataWithContentsOfFile:cerPath];
                NSCAssert(caCert != nil, @"caCert is nil");
                if(nil == caCert)
                    break; /* failed */
                
                SecCertificateRef caRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)caCert);
                NSCAssert(caRef != nil, @"caRef is nil");
                if(nil == caRef)
                    break; /* failed */
                
                if(nil == caArray) {
                    caArray = [NSMutableArray new];
                }
                
                [caArray addObject:(__bridge id)(caRef)];
                
            }
            
            NSCAssert(caArray != nil, @"caArray is nil");
            if(nil == caArray)
                break; /* failed */
            
            
            //将读取的证书设置为服务端帧数的根证书
            OSStatus status = SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)caArray);
            NSCAssert(errSecSuccess == status, @"SecTrustSetAnchorCertificates failed");
            if(!(errSecSuccess == status))
                break; /* failed */
            
            SecTrustResultType result = -1;
            //通过本地导入的证书来验证服务器的证书是否可信
            status = SecTrustEvaluate(serverTrust, &result);
            if(!(errSecSuccess == status))
                break; /* failed */
            DLog(@"stutas:%d",(int)status);
            DLog(@"Result: %d", result);
            
            BOOL allowConnect = (result == kSecTrustResultUnspecified) || (result == kSecTrustResultProceed);
            if (allowConnect) {
                DLog(@"success");
            }else {
                DLog(@"error");
            }
            
            if(! allowConnect) {
                break;
            }
            
            if(result == kSecTrustResultDeny || result == kSecTrustResultFatalTrustFailure || result == kSecTrustResultOtherError)
                break;

            DLog(@"信任该证书");
            return [[challenge sender] useCredential: [NSURLCredential credentialForTrust: serverTrust]
                          forAuthenticationChallenge: challenge];
            
        }
        while(0);
    }
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
    
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}



- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if ([self isCancelled]) {
        [connection cancel];
        connection = nil;
        return;
    }
    
    [_result appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    DLog(@"%s", __func__);
    DLog(@"[ERROR] >>> %@", error);
    
    [connection cancel];
    _result = nil;
    connection = nil;
    if (_isImage) {
        if (_nsDataHandler != nil) {
            _nsDataHandler(nil);
        }
    }
    else{
        if (_handler != nil) {
            _handler(nil);
        }
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSData *result = [[_result copy] gunzippedData];
    if(result == nil){
        result = [_result copy];
    }
    if (_isImage&&_nsDataHandler!=nil) {
        _nsDataHandler(result);
    }
    else if (_handler != nil) {
        id jsonObject = [result objectFromJSONData];
        if (jsonObject == nil) {
            jsonObject = [[self dataDecode:result] objectFromJSONString];
        }
        _handler(jsonObject);
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

- (NSData *)dataEncode:(NSData *)data {
    if (data == nil) {
        return nil;
    }
    
    Byte *byte = (Byte *)[data bytes];
    for (int i = 0; i < [data length]; i++) {
        *(byte+i) = *(byte+i) + 8;
    }
    return [NSData dataWithBytes:byte length:[data length]];
 
//    return [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];
}




- (void)dealloc {
    //DLog(@"%s", __func__);
    _nsDataHandler=nil;
    _handler = nil;
    _result = nil;
}


#pragma mark - getter
- (NSMutableArray *)cerFiles {
    
    if(nil == _cerFiles) {
        [staticFileArray removeAllObjects];
        NSString *path = [[NSBundle mainBundle]bundlePath];
        [staticFileArray removeAllObjects];
        _cerFiles = [self getCerFiles:path];
    }
    
    return _cerFiles;
}


#pragma mark - privated methods
static NSMutableArray * staticFileArray;//由于是递归方法中共用了同一个数组，所以设为静态变量，在使用前记得置NULL
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
            
            if(nil == staticFileArray) {
                staticFileArray = [NSMutableArray new];
            }
            if([path rangeOfString:@".cer"].location != NSNotFound) {
                DLog(@"%@",path);
                [staticFileArray addObject:path];
            }
        }
    }else{
        DLog(@"你打印的是目录或者不存在");
        return nil;
    }
    return staticFileArray;
}

@end
