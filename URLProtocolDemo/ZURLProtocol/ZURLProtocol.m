//
//  ZURLProtocol.m
//  URLProtocolDemo
//
//  Created by zly on 16/5/10.
//  Copyright © 2016年 zly. All rights reserved.
//

#import "ZURLProtocol.h"
#import "Lib/Reachability.h"

@interface ZURLProtocol ()
@property (nonatomic, strong) NSURLConnection *connection;
@end

static NSString *ZURLHeader = @"X-ZCache";

static NSObject *ZCachingSupportedSchemesMonitor;
static NSSet *ZCachingSupportedSchemes;

@implementation ZURLProtocol

/**
 *  初始化
 */
+(void)Init
{
    [NSURLProtocol registerClass:[ZURLProtocol class]];
}

/**
 *  释放
 */
+(void)UnInit
{
    [NSURLProtocol unregisterClass:[ZURLProtocol class]];
}

/**
 *  设置缓存
 *
 *  @param nMemorySize 内存缓存大小，单位为m
 *  @param nDiskSize   磁盘缓存大小，单位为m
 *  @param strDiskPath 磁盘缓存路径
 */
+ (void)SetCacheMemory:(NSUInteger)nMemorySize diskSize:(NSUInteger)nDiskSize diskPath:(NSString *)strDiskPath
{
    NSURLCache *urlCache = [[NSURLCache alloc] initWithMemoryCapacity:nMemorySize*1024*1024 diskCapacity:nDiskSize*1024*1024 diskPath:strDiskPath];
    [NSURLCache setSharedURLCache:urlCache];
}



+ (void)initialize
{
    if (self == [ZURLProtocol class])
    {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^
        {
            ZCachingSupportedSchemesMonitor = [NSObject new];
        });
        
        [self setSupportedSchemes:[NSSet setWithObject:@"http"]];
    }
}

//get schemes which need cache ofZine
+ (NSSet *)supportedSchemes
{
    NSSet *supportedSchemes;
    @synchronized(ZCachingSupportedSchemesMonitor)
    {
        supportedSchemes = ZCachingSupportedSchemes;
    }
    return supportedSchemes;
}

//set schemes which need cache offline
+ (void)setSupportedSchemes:(NSSet *)supportedSchemes
{
    @synchronized(ZCachingSupportedSchemesMonitor)
    {
        ZCachingSupportedSchemes = supportedSchemes;
    }
}


#pragma mark - NSURLProtocol methods
/**
 *  处理对应的request，
    如果不处理，返回NO，URL Loading System会使用系统默认的行为去处理；
    如果处理，返回YES，然后你就需要处理该请求的所有东西，包括获取请求数据并返回给 URL Loading System。
 *
 *  @param request
 *
 *  @return
 */
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    if ([[self supportedSchemes] containsObject:request.URL.scheme]
        && [request valueForHTTPHeaderField:ZURLHeader] == nil)
    {
        return YES;
    }
    
    return NO;
}

/**
 *  通常该方法你可以简单的直接返回request
    但也可以在这里修改request，比如添加header，修改host等，并返回一个新的request
    这是一个抽象方法，子类必须实现。(用于重定向)
 *
 *  @param request
 *
 *  @return
 */
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    return request;
    
//    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
//    mutableReqeust = [self redirectHostInRequset:mutableReqeust];
//    return mutableReqeust;
}

/**
 *  重定向
 *
 *  @param request <#request description#>
 *
 *  @return <#return value description#>
 */
+(NSMutableURLRequest*)redirectHostInRequset:(NSMutableURLRequest*)request
{
    if ([request.URL host].length == 0)
    {
        return request;
    }
    
    NSString *originUrlString = [request.URL absoluteString];
    NSString *originHostString = [request.URL host];
    NSRange hostRange = [originUrlString rangeOfString:originHostString];
    if (hostRange.location == NSNotFound)
    {
        return request;
    }
    //定向到bing搜索主页
    NSString *ip = @"cn.bing.com";
    
    // 替换域名
    NSString *urlString = [originUrlString stringByReplacingCharactersInRange:hostRange withString:ip];
    NSURL *url = [NSURL URLWithString:urlString];
    request.URL = url;
    
    return request;
}

/**
 *  判断两个request是否相同，如果相同的话可以使用缓存数据，通常只需要调用父类的实现。
 *
 *  @param a <#a description#>
 *  @param b <#b description#>
 *
 *  @return <#return value description#>
 */
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b {
    return [super requestIsCacheEquivalent:a toRequest:b];
}

//开始request
- (void)startLoading
{
    NSCachedURLResponse *response = [[NSURLCache sharedURLCache] cachedResponseForRequest:self.request];
    NSMutableURLRequest *connectionRequest = [self.request mutableCopy];
    [connectionRequest setValue:@"" forHTTPHeaderField:ZURLHeader];
    if ([self networkReachable])
    {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response.response;
        if (httpResponse)
        {
            [connectionRequest setValue:httpResponse.allHeaderFields[@"Last-Modified"] forHTTPHeaderField:@"Last-Modified"];
            [connectionRequest setValue:httpResponse.allHeaderFields[@"Etag"] forHTTPHeaderField:@"Etag"];
        }
        self.connection = [NSURLConnection connectionWithRequest:connectionRequest delegate:self];
    }
    else if (response)
    {
        [self.client URLProtocol:self didReceiveResponse:response.response cacheStoragePolicy:NSURLCacheStorageAllowed];
        [self.client URLProtocol:self didLoadData:response.data];
        [self.client URLProtocolDidFinishLoading:self];
    }
    else
    {
        [self.client URLProtocol:self didFailWithError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotConnectToHost userInfo:nil]];
    }
}

//取消request
- (void)stopLoading
{
    [self.connection cancel];
}

#pragma mark - NSURLConnectionDataDelegate methods
//在处理网络请求的时候会调用到该代理方法，我们需要将收到的消息通过client返回给URL Loading System。
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    if (httpResponse && httpResponse.statusCode == 304)
    {
        NSCachedURLResponse *cachedResponse = [[NSURLCache sharedURLCache] cachedResponseForRequest:self.request];
        if (cachedResponse)
        {
            [self.client URLProtocol:self didReceiveResponse:cachedResponse.response cacheStoragePolicy:NSURLCacheStorageAllowed];
            [self.client URLProtocol:self didLoadData:cachedResponse.data];
            [self.client URLProtocolDidFinishLoading:self];
        }
    }
    else
    {
        [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    [self.client URLProtocol:self didLoadData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    [self.client URLProtocolDidFinishLoading:self];
    self.connection = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    [self.client URLProtocol:self didFailWithError:error];
    self.connection = nil;
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection willCacheResponse:(NSCachedURLResponse *)cachedResponse
{
    return cachedResponse;
}

- (BOOL)networkReachable
{
    return [[Reachability reachabilityWithHostName:self.request.URL.host] currentReachabilityStatus] != NotReachable;
}

@end
