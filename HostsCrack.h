// ============================================================
//  HostsCrack.h — hosts 改写与证书安装辅助
//
//  用途：在 CoreCrack 内尝试改写 /etc/hosts，
//        把 order.klpjwycb.xyz 指向假服务器。
//        若权限不足，会给出明确提示。
// ============================================================

#import <Foundation/Foundation.h>

@interface HostsCrack : NSObject

// 检查是否有权限写 /etc/hosts
+ (NSDictionary *)checkHostsPermission;

// 尝试把 domain 指向 ip（会备份原文件）
+ (NSDictionary *)redirectDomain:(NSString *)domain toIP:(NSString *)ip;

// 恢复 hosts 备份
+ (NSDictionary *)restoreHosts;

@end
