//
//  MTURLSessionManager.m
//  UICommon
//
//  Created by xiuyuan on 2018/9/1.
//  Copyright © 2018年 YN. All rights reserved.
//

#import "MTURLSessionManager.h"


#pragma mark - define
static dispatch_queue_t mt_url_session_manager_creation_queue() {
    static dispatch_queue_t _mt_url_session_manager_creation_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _mt_url_session_manager_creation_queue = dispatch_queue_create("cn.mastercom.networking.session.manager.creation", DISPATCH_QUEUE_SERIAL);
    });
    
    return _mt_url_session_manager_creation_queue;
}

static dispatch_queue_t mt_url_session_manager_processing_queue() {
    static dispatch_queue_t _mt_url_session_manager_processing_queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _mt_url_session_manager_processing_queue = dispatch_queue_create("cn.mastercom.networking.session.manager.processing", DISPATCH_QUEUE_CONCURRENT);
    });
    
    return _mt_url_session_manager_processing_queue;
}

static dispatch_group_t mt_url_session_manager_completion_group() {
    static dispatch_group_t _mt_url_session_manager_completion_group;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _mt_url_session_manager_completion_group = dispatch_group_create();
    });
    
    return _mt_url_session_manager_completion_group;
}

NSString * const MTNetworkingTaskDidCompleteSerializedResponseKey = @"cn.mastercom.networking.task.complete.serializedresponse";
NSString * const MTNetworkingTaskDidCompleteResponseSerializerKey = @"cn.mastercom.networking.task.complete.responseserializer";
NSString * const MTNetworkingTaskDidCompleteResponseDataKey = @"cn.mastercom.networking.complete.finish.responsedata";
NSString * const MTNetworkingTaskDidCompleteErrorKey = @"cn.mastercom.networking.task.complete.error";
NSString * const MTNetworkingTaskDidCompleteAssetPathKey = @"cn.mastercom.networking.task.complete.assetpath";

static NSString * const MTURLSessionManagerLockName = @"cn.mastercom.networking.session.manager.lock";

typedef void (^MTURLSessionTaskCompletionHandler)(NSURLResponse *response, id responseObject, NSError *error);




#pragma mark - MTURLSessionManagerTaskProcess
@interface MTURLSessionManagerTaskProcessor : NSObject
@property (nonatomic, strong) NSMutableData *mutableData;
@property (nonatomic, strong) NSProgress *progress;
@property (nonatomic, copy) MTURLSessionTaskCompletionHandler completionHandler;
@end

@implementation MTURLSessionManagerTaskProcessor
- (instancetype)init {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    self.mutableData = [NSMutableData data];
    
    self.progress = [NSProgress progressWithTotalUnitCount:0];
    
    return self;
}

#pragma mark - NSURLSessionTaskDelegate

- (void)processURLSession:(__unused NSURLSession *)session
                     task:(__unused NSURLSessionTask *)task
          didSendBodyData:(__unused int64_t)bytesSent
           totalBytesSent:(int64_t)totalBytesSent
 totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    self.progress.totalUnitCount = totalBytesExpectedToSend;
    self.progress.completedUnitCount = totalBytesSent;
}

- (void)processURLSession:(__unused NSURLSession *)session
                     task:(NSURLSessionTask *)task
     didCompleteWithError:(NSError *)error
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wgnu"
    __block id responseObject = nil;
    
    if (error) {
        dispatch_group_async(mt_url_session_manager_completion_group(), dispatch_get_main_queue(), ^{
            if (self.completionHandler) {
                self.completionHandler(task.response, responseObject, error);
            }
        });
    } else {
        dispatch_async(mt_url_session_manager_processing_queue(), ^{
            NSError *serializationError = nil;

            //TODO:  data -> jsonObj
            NSData *jsonData = [[self.mutableData copy] gunzippedData];
            if (!jsonData) {
                jsonData = [self.mutableData copy];
            }
            
            responseObject = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&serializationError];
            if (!responseObject) {
                jsonData = [[self dataDecode:jsonData] dataUsingEncoding:NSUTF8StringEncoding];
                if (jsonData) {
                    responseObject = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&serializationError];
                }

            }
            
            dispatch_group_async(mt_url_session_manager_completion_group(), dispatch_get_main_queue(), ^{
                if (self.completionHandler) {
                    self.completionHandler(task.response, responseObject, serializationError);
                }
            });
        });
    }
#pragma clang diagnostic pop
}



- (void)processURLSession:(__unused NSURLSession *)session
                 dataTask:(__unused NSURLSessionDataTask *)dataTask
           didReceiveData:(NSData *)data
{
    [self.mutableData appendData:data];
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





@end





#pragma mark - MTURLSessionManager

@interface MTURLSessionManager ()<NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

@property (readwrite, nonatomic, strong) NSURLSessionConfiguration *sessionConfiguration;
@property (readwrite, nonatomic, strong) NSOperationQueue *operationQueue;
@property (readwrite, nonatomic, strong) NSURLSession *session;
@property (readwrite, nonatomic, strong) NSLock *lock;
@property (readwrite, nonatomic, strong) NSMutableDictionary *processorsKeyedByTaskIdentifier;
@property (nonatomic, strong) NSMutableArray *cerFiles;
@end


@implementation MTURLSessionManager

- (instancetype)init {
    
    if (self = [super init]) {
        
        self.sessionConfiguration = [NSURLSessionConfiguration defaultSessionConfiguration];
        
        self.operationQueue = [[NSOperationQueue alloc] init];
        self.operationQueue.maxConcurrentOperationCount = 1;
        
        self.session = [NSURLSession sessionWithConfiguration:self.sessionConfiguration delegate:self delegateQueue:self.operationQueue];
        
        self.processorsKeyedByTaskIdentifier = [[NSMutableDictionary alloc] init];
        
        self.lock = [[NSLock alloc] init];
        self.lock.name = MTURLSessionManagerLockName;
        
        [self.session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {

            for (NSURLSessionDataTask *task in dataTasks) {
                [self addProcessorForDataTask:task completionHandler:nil];
            }
            
//            for (NSURLSessionUploadTask *uploadTask in uploadTasks) {
//                [self addDelegateForUploadTask:uploadTask progress:nil completionHandler:nil];
//            }
//
//            for (NSURLSessionDownloadTask *downloadTask in downloadTasks) {
//                [self addDelegateForDownloadTask:downloadTask progress:nil destination:nil completionHandler:nil];
//            }
        }];
    }
    return self;
}

- (void)dealloc {
    NSLog(@"%s", __func__);
}

#pragma mark - processor
- (MTURLSessionManagerTaskProcessor *)processorForTask:(NSURLSessionTask *)task {
    NSParameterAssert(task);
    
    MTURLSessionManagerTaskProcessor *processor = nil;
    [self.lock lock];
    processor = self.processorsKeyedByTaskIdentifier[@(task.taskIdentifier)];
    [self.lock unlock];
    
    return processor;
}

- (void)setProcessor:(MTURLSessionManagerTaskProcessor *)processor forTask:(NSURLSessionDataTask *)task
{
    NSParameterAssert(task);
    NSParameterAssert(processor);
    [self.lock lock];
    self.processorsKeyedByTaskIdentifier[@(task.taskIdentifier)] = processor;
    [self.lock unlock];
}

- (void)addProcessorForDataTask:(NSURLSessionDataTask *)task completionHandler:(MTURLSessionTaskCompletionHandler)handler
{
    MTURLSessionManagerTaskProcessor *processor = [[MTURLSessionManagerTaskProcessor alloc] init];
    processor.completionHandler = handler;
    
    [self setProcessor:processor forTask:task];
}


- (void)removeProcessorForTask:(NSURLSessionTask *)task {
    NSParameterAssert(task);
    
    [self.lock lock];
    [self.processorsKeyedByTaskIdentifier removeObjectForKey:@(task.taskIdentifier)];
    [self.lock unlock];
}

- (void)removeAllDelegates {
    [self.lock lock];
    [self.processorsKeyedByTaskIdentifier removeAllObjects];
    [self.lock unlock];
}


#pragma mark - public
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSURLResponse *response, id responseObject, NSError *error))completionHandler
{
    __block NSURLSessionDataTask *dataTask = nil;
    dispatch_sync(mt_url_session_manager_creation_queue(), ^{
        dataTask = [self.session dataTaskWithRequest:request];
    });
    
    [self addProcessorForDataTask:dataTask completionHandler:completionHandler];
    
    return dataTask;
}

- (void)invalidateSessionCancelingTasks:(BOOL)cancelPendingTasks {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (cancelPendingTasks) {
            [self.session invalidateAndCancel];
        } else {
            [self.session finishTasksAndInvalidate];
        }
    });
}


#pragma mark - NSURLSessionDelegate
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error
{
    
}


/**
 *  目前只有云会议走的是HTTPS通道，需要验证证书
 *  证书的验证规则还是沿用以前的规则，
 *  验证云会议本地保存的ca.cer证书
 */
- (void)URLSession:(NSURLSession *)session
didReceiveChallenge:(nonnull NSURLAuthenticationChallenge *)challenge
 completionHandler:(nonnull void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    if ([[[challenge protectionSpace] authenticationMethod] isEqualToString: NSURLAuthenticationMethodServerTrust]) {
        SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
        NSCAssert(serverTrust != nil, @"serverTrust is nil");
        if(nil == serverTrust)
            return ;
        
        //从NSBundle中导入多张CA证书（Certification Authority，支持SSL证书以及自签名的CA
        NSMutableArray *caArray;
        for (NSString *cerPath in self.cerFiles) {
            NSData* caCert = [NSData dataWithContentsOfFile:cerPath];
            NSCAssert(caCert != nil, @"caCert is nil");
            if(nil == caCert)
                return ;
            
            SecCertificateRef caRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)caCert);
            NSCAssert(caRef != nil, @"caRef is nil");
            if(nil == caRef)
                return ;
            
            if(nil == caArray) {
                caArray = [NSMutableArray new];
            }
            
            [caArray addObject:(__bridge id)(caRef)];
            
        }
        
        NSCAssert(caArray != nil, @"caArray is nil");
        if(nil == caArray)
            return ;
        
        
        //将读取的证书设置为服务端帧数的根证书
        OSStatus status = SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)caArray);
        NSCAssert(errSecSuccess == status, @"SecTrustSetAnchorCertificates failed");
        if(!(errSecSuccess == status))
            return ;
        
        SecTrustResultType result = -1;
        //通过本地导入的证书来验证服务器的证书是否可信
        status = SecTrustEvaluate(serverTrust, &result);
        if(!(errSecSuccess == status))
            return ;
        
        DLog(@"stutas:%d",(int)status);
        DLog(@"Result: %d", result);
        
        BOOL allowConnect = (result == kSecTrustResultUnspecified) || (result == kSecTrustResultProceed);
        if (allowConnect) {
            DLog(@"success");
        }else {
            DLog(@"error");
        }
        
        if(! allowConnect) {
            return ;
        }
        
        if(result == kSecTrustResultDeny || result == kSecTrustResultFatalTrustFailure || result == kSecTrustResultOtherError)
            return ;
        
        DLog(@"信任该证书");
        completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:serverTrust]);
    }
}



- (NSMutableArray *)cerFiles {
    
    if(!_cerFiles) {
        NSString *mainBundlePath = [[NSBundle mainBundle] bundlePath];
        NSMutableArray *cerFilePathArray = [NSMutableArray array];
        [self findCerFilePathToArray:cerFilePathArray inDir:mainBundlePath];
        _cerFiles = [cerFilePathArray mutableCopy];
    }
    
    return _cerFiles;
}

- (void)findCerFilePathToArray:(NSMutableArray *)cerFilePathArray inDir:(NSString *)dirPath
{
    NSFileManager * fileManger = [NSFileManager defaultManager];
    if ([fileManger fileExistsAtPath:dirPath]) {
        NSError *findErr;
        [[fileManger contentsOfDirectoryAtPath:dirPath error:&findErr] enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *subfilePath = [dirPath stringByAppendingPathComponent:obj];
            BOOL isDir = NO;
            if ([fileManger fileExistsAtPath:subfilePath isDirectory:&isDir]) {
                if (isDir) { //是文件夹
                    [self findCerFilePathToArray:cerFilePathArray inDir:subfilePath];
                } else {
                    if ([subfilePath hasSuffix:@".cer"]) { //是HTTPS证书
                        [cerFilePathArray addObject:subfilePath];
                    }
                }
            } else {
                DLog(@"subfilePath<%@> doesn't exist", subfilePath);
            }
        }];
    } else {
        DLog(@"dirPath<%@> doesn't exist", dirPath);
    }
}


#pragma mark - NSURLSessionTaskDelegate




#pragma mark - NSURLSessionDataDelegate
- (void)URLSession:(NSURLSession *)session
          dataTask:(nonnull NSURLSessionDataTask *)dataTask
    didReceiveData:(nonnull NSData *)data
{
    MTURLSessionManagerTaskProcessor *processor = [self processorForTask:dataTask];
    [processor processURLSession:session dataTask:dataTask didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
   didSendBodyData:(int64_t)bytesSent
    totalBytesSent:(int64_t)totalBytesSent
totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    int64_t totalUnitCount = totalBytesExpectedToSend;
    if(totalUnitCount == NSURLSessionTransferSizeUnknown) {
        NSString *contentLength = [task.originalRequest valueForHTTPHeaderField:@"Content-Length"];
        if(contentLength) {
            totalUnitCount = (int64_t) [contentLength longLongValue];
        }
    }
    
    MTURLSessionManagerTaskProcessor *processor = [self processorForTask:task];
    [processor processURLSession:session task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalUnitCount];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    MTURLSessionManagerTaskProcessor *processor = [self processorForTask:task];
    // delegate(session.delegate) may be nil when completing a task in the background
    
    if (processor) {
        [processor processURLSession:session task:task didCompleteWithError:error];
        
        [self removeProcessorForTask:task];
    }
    
    // 区别于AFN中的使用
    // AFHTTPSessionManager是写成单例持有，保证不会一直的新建实例，所以不会出现内存泄漏
    // 这里由于以前的设计，只是修改了原有的自定义方法
    [self.session finishTasksAndInvalidate];
}
@end
