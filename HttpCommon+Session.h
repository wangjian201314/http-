//
//  HttpCommon+Session.h
//  UICommon
//
//  Created by xiuyuan on 2018/9/1.
//  Copyright © 2018年 YN. All rights reserved.
//

#import "HttpCommon.h"



/** URL编码策略
 *
 *  部分json数据中的值需要编码的处理
 *  防止在提交数据时value中存在特殊字符导致提交失败 eg: !@#$%^&*
 *
 *  请在传值部分自行处理
 *  根据需求处理是否是整体转码还是只对值转码
 *
 *  整体转码：@"json":[[jsonDic JSONString] urlEncode]
 *
 *  value转码：
 *  NSString *jsonDataStr = requestParams[@"json"];
 *  if (jsonDataStr) {
 *     NSDictionary *jsonDic = (NSDictionary *)[jsonDataStr objectFromJSONString];
 *     NSMutableDictionary *tempJsonDic = [NSMutableDictionary dictionary];
 *     [jsonDic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
 *         NSString *value = [obj urlEncode];
 *         [tempJsonDic setValue:value forKey:key];
 *     }];
 *     jsonDataStr = [tempJsonDic JSONString];
 *     requestParams[@"json"] = jsonDataStr;
 *    }
 *
 */



/** 超时重新请求策略
 *
 *  默认超时时长 90s
 *
 *  超时回调 MessageTimeOutHandler timeOutHandler
 *  当请求超时之后，网络组件会根据 timeOutHandler 回调将消息回传（有待验证，只满足某种情况才会调用）
 *  timeOutHandler 除了做回调，在流程控制中还做了BOOL值判断作用，
 *  如果timeOutHandler不为空，则执行 backGroundReloginTimeOutHandler:Handler: 方法，在这个方法里面会重新组织一次网络请求，并且在这个网络请求中将timeOutHandler置为nil，防止出现死循环
 */




/**
 *  MTZIP 编码说明
 *  在 UICommon 工程下可以搜到 MTZIP 一个宏，值默认为1
 *  原网络请求中是通过重写 HTTPCommonOperation 的初始化函数来实现配置 MTZIP 的，这几个方法最终将不会执行全自定义的方法，故不影响全自定义里面的实现
 */






@interface HttpCommon (Session)

@end
