// ============================================================
//  DomainSwap.m — 等长替换 Core 里的服务器域名
// ============================================================

#import "DomainSwap.h"

@implementation DomainSwap

+ (NSDictionary *)scanDomains:(NSString *)binPath {
    NSMutableDictionary *r = [NSMutableDictionary dictionary];
    NSData *data = [NSData dataWithContentsOfFile:binPath];
    if (!data) { r[@"错误"] = @"读不到二进制"; return r; }

    NSArray *candidates = @[
        @"order.klpjwycb.xyz",
        @"klpjwycb.xyz",
        @"order.xidudexi.xyz",
        @"xidudexi.xyz",
    ];

    const unsigned char *bytes = [data bytes];
    NSUInteger len = [data length];

    for (NSString *cand in candidates) {
        NSData *needle = [cand dataUsingEncoding:NSUTF8StringEncoding];
        const unsigned char *n = [needle bytes];
        NSUInteger nlen = [needle length];
        NSMutableArray *offsets = [NSMutableArray array];

        if (nlen == 0 || nlen > len) continue;
        for (NSUInteger i = 0; i + nlen <= len; i++) {
            if (bytes[i] != n[0]) continue;
            if (memcmp(bytes + i, n, nlen) == 0) {
                [offsets addObject:[NSString stringWithFormat:@"0x%lX", (unsigned long)i]];
                if (offsets.count > 20) break;
            }
        }
        if (offsets.count > 0) {
            r[cand] = [NSString stringWithFormat:@"%lu 处: %@",
                       (unsigned long)offsets.count,
                       [offsets componentsJoinedByString:@", "]];
        }
    }
    return r;
}

+ (NSDictionary *)swapDomainInFile:(NSString *)binPath
                        fromDomain:(NSString *)oldDomain
                          toDomain:(NSString *)newDomain {
    NSMutableDictionary *r = [NSMutableDictionary dictionary];

    if (oldDomain.length != newDomain.length) {
        r[@"结果"] = [NSString stringWithFormat:
            @"❌ 长度不等：%@(%lu) vs %@(%lu)",
            oldDomain, (unsigned long)oldDomain.length,
            newDomain, (unsigned long)newDomain.length];
        return r;
    }

    NSData *data = [NSData dataWithContentsOfFile:binPath];
    if (!data) { r[@"结果"] = @"❌ 读不到二进制"; return r; }

    NSMutableData *md = [data mutableCopy];
    unsigned char *bytes = [md mutableBytes];
    NSUInteger len = [md length];

    NSData *needleD = [oldDomain dataUsingEncoding:NSUTF8StringEncoding];
    const unsigned char *n = [needleD bytes];
    NSUInteger nlen = [needleD length];

    NSData *replD = [newDomain dataUsingEncoding:NSUTF8StringEncoding];
    const unsigned char *rep = [replD bytes];

    int hits = 0;
    for (NSUInteger i = 0; i + nlen <= len; i++) {
        if (bytes[i] != n[0]) continue;
        if (memcmp(bytes + i, n, nlen) == 0) {
            memcpy(bytes + i, rep, nlen);
            hits++;
            i += nlen - 1;
        }
    }

    if (hits == 0) {
        r[@"结果"] = [NSString stringWithFormat:@"⚠️ 没找到 '%@'", oldDomain];
        return r;
    }

    // 写回
    NSError *err = nil;
    BOOL ok = [md writeToFile:binPath options:NSDataWritingAtomic error:&err];
    if (ok) {
        r[@"结果"] = [NSString stringWithFormat:@"✅ 已替换 %d 处", hits];
        r[@"替换"] = [NSString stringWithFormat:@"%@ -> %@", oldDomain, newDomain];
        r[@"提示"] = @"还需重签名（ldid -S）才能运行！";
    } else {
        r[@"结果"] = [NSString stringWithFormat:@"❌ 写回失败：%@", err.localizedDescription];
    }
    return r;
}

@end
