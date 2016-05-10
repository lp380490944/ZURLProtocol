//
//  ZURLProtocol.h
//  URLProtocolDemo
//
//  Created by zly on 16/5/10.
//  Copyright © 2016年 zly. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  缓存网络请求、重定向
 */
@interface ZURLProtocol : NSURLProtocol

/**
 *  初始化
 */
+(void)Init;

/**
 *  释放
 */
+(void)UnInit;

/**
 *  设置缓存
 *
 *  @param nMemorySize 内存缓存大小，单位为m
 *  @param nDiskSize   磁盘缓存大小，单位为m
 *  @param strDiskPath 磁盘缓存路径
 */
+ (void)SetCacheMemory:(NSUInteger)nMemorySize diskSize:(NSUInteger)nDiskSize diskPath:(NSString *)strDiskPath;


+ (NSSet *)supportedSchemes;
+ (void)setSupportedSchemes:(NSSet *)supportedSchemes;

@end
