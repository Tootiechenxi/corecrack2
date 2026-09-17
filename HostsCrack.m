// ============================================================
//  HostsCrack.m — hosts 改写实现
//
//  在 CoreCrack 内尝试改写 /etc/hosts。
//  若 App 无权限（TrollStore 普通沙盒），会明确报错。
// ============================================================

#import "HostsCrack.h"

#define HOSTS_PATH @"/etc/hosts"
#define HOSTS_BAK  @"/etc/hosts.corecrack.bak"

@implementation HostsCrack

+ (NSDictionary *)checkHostsPermission {
    NSMutableDictionary *r = [NSMutableDictionary dictionary];
    NSFileManager *fm = [NSFileManager defaultManager];

    // 1. 文件是否存在
    BOOL exists = [fm fileExistsAtPath:HOSTS_PATH];
    r[@"hosts存在"] = exists ? @"是" : @"否";

    // 2. 是否可读
    BOOL readable = [fm isReadableFileAtPath:HOSTS_PATH];
    r[@"可读"] = readable ? @"是" : @"否";

    // 3. 是否可写
    BOOL writable = [fm isWritableFileAtPath:HOSTS_PATH];
    r[@"可写"] = writable ? @"是" : @"否";

    // 4. 当前 hosts 内容
    NSString *content = [NSString stringWithContentsOfFile:HOSTS_PATH
                                                  encoding:NSUTF8StringEncoding error:nil];
    r[@"当前内容"] = content ? content : @"(读不到)";

    // 5. 是否已经有我们的劫持条目
    if (content && [content containsString:@"order.klpjwycb.xyz"]) {
        r[@"已有劫持条目"] = @"是";
    } else {
        r[@"已有劫持条目"] = @"否";
    }

    return r;
}

+ (NSDictionary *)redirectDomain:(NSString *)domain toIP:(NSString *)ip {
    NSMutableDictionary *r = [NSMutableDictionary dictionary];
    NSFileManager *fm = [NSFileManager defaultManager];

    // 读原内容
    NSString *content = [NSString stringWithContentsOfFile:HOSTS_PATH
                                                  encoding:NSUTF8StringEncoding error:nil];
    if (!content) {
        r[@"结果"] = @"❌ 无法读取 /etc/hosts（无权限）";
        r[@"建议"] = @"Filza 手动改，或用 DNS 方案";
        return r;
    }

    // 备份（只在首次备份）
    if (![fm fileExistsAtPath:HOSTS_BAK]) {
        BOOL bak = [content writeToFile:HOSTS_BAK atomically:YES
                               encoding:NSUTF8StringEncoding error:nil];
        r[@"备份"] = bak ? @"✅ 已备份到 /etc/hosts.corecrack.bak" : @"⚠️ 备份失败（继续尝试）";
    } else {
        r[@"备份"] = @"已存在备份，未覆盖";
    }

    // 构造新内容（先移除旧的同类条目，再追加）
    NSMutableArray *lines = [NSMutableArray array];
    for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
        if ([line containsString:domain]) continue;  // 去掉旧条目
        [lines addObject:line];
    }
    [lines addObject:[NSString stringWithFormat:@"%@\t%@\t# CoreCrack", ip, domain]];

    NSString *newContent = [lines componentsJoinedByString:@"\n"];

    NSError *err = nil;
    BOOL ok = [newContent writeToFile:HOSTS_PATH atomically:YES
                             encoding:NSUTF8StringEncoding error:&err];
    if (ok) {
        r[@"结果"] = [NSString stringWithFormat:@"✅ 已写入：%@ -> %@", domain, ip];
        r[@"提示"] = @"若 Core 仍不走假服务器，可能有 DNS 缓存，重启 Core 或切换飞行模式";
    } else {
        r[@"结果"] = [NSString stringWithFormat:@"❌ 写入失败：%@", err.localizedDescription];
        r[@"建议"] = @"权限不足，需用 Filza(root) 或越狱环境改 hosts";
    }
    return r;
}

+ (NSDictionary *)restoreHosts {
    NSMutableDictionary *r = [NSMutableDictionary dictionary];
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:HOSTS_BAK]) {
        r[@"结果"] = @"⚠️ 没有备份文件，无法恢复";
        return r;
    }
    NSString *bak = [NSString stringWithContentsOfFile:HOSTS_BAK
                                              encoding:NSUTF8StringEncoding error:nil];
    if (!bak) { r[@"结果"] = @"❌ 备份读取失败"; return r; }
    BOOL ok = [bak writeToFile:HOSTS_PATH atomically:YES
                      encoding:NSUTF8StringEncoding error:nil];
    r[@"结果"] = ok ? @"✅ 已恢复原始 hosts" : @"❌ 恢复失败";
    return r;
}

@end
