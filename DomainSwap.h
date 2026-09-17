// ============================================================
//  DomainSwap.m — 把 Core 里的服务器域名等长替换
//
//  原理：https://order.klpjwycb.xyz  (18 字符域名)
//        https://order.xidudexi.xyz  (18 字符域名) ← 完全等长
//        在二进制里直接覆盖字节，不破坏任何结构。
//
//  替换后：Core 会请求 order.xidudexi.xyz，
//          而该域名由你的 Caddy 提供真证书 + 假响应。
// ============================================================

#import <Foundation/Foundation.h>

@interface DomainSwap : NSObject

// 在指定二进制里把 oldDomain 等长替换成 newDomain
+ (NSDictionary *)swapDomainInFile:(NSString *)binPath
                         fromDomain:(NSString *)oldDomain
                           toDomain:(NSString *)newDomain;

// 检查二进制里有哪些相关域名
+ (NSDictionary *)scanDomains:(NSString *)binPath;

@end
