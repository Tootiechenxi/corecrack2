// ============================================================
//  CoreCrack.m — 一键三连破解实现
//
//  架构：三刀中，第 1 刀（hasLocalActivationCard，无参返回 BOOL）
//        可静态 patch（mov w0,#1; ret），最干净。
//
//        第 2、3 刀（带 completion block 的异步方法）静态 patch 易崩，
//        故采用「运行时 hook」优先：本 App 启动后注入一个
//        精简的运行时替换（用 method_setImplementation），
//        把三个方法直接换成假实现，比改字节更稳。
//
//  因此本文件提供两条路径：
//    A. patchHasLocalActivationCardAtPath:  -> 静态改字节（真·永久）
//    B. hookRuntime:                       -> 运行时替换 IMP（推荐，稳）
// ============================================================

#import "CoreCrack.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <sys/stat.h>
#import <spawn.h>

extern char **environ;   // 全局环境变量（posix_spawn 需要）

@implementation CoreCrack

// —— Mach-O 常量 ——
#define MH_MAGIC_64 0xFEEDFACF

static inline uint32_t r32(const unsigned char *p, uint32_t o) {
    uint32_t v; memcpy(&v, p + o, 4); return v;
}
static inline uint64_t r64(const unsigned char *p, uint32_t o) {
    uint64_t v; memcpy(&v, p + o, 8); return v;
}

// ============ 工具：定位 ============
+ (NSString *)locateCoreBinary {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *bases = @[ @"/var/containers/Bundle/Application",
                        @"/private/var/containers/Bundle/Application" ];
    for (NSString *base in bases) {
        for (NSString *uuid in [fm contentsOfDirectoryAtPath:base error:nil]) {
            NSString *coreApp = [base stringByAppendingPathComponent:
                                 [uuid stringByAppendingPathComponent:@"Core.app"]];
            NSString *coreBin = [coreApp stringByAppendingPathComponent:@"Core"];
            if ([fm fileExistsAtPath:coreBin]) return coreBin;
        }
    }
    return nil;
}

+ (NSInteger)findBytes:(const unsigned char *)hay hayLen:(uint64_t)hlen
                needle:(const unsigned char *)n needleLen:(uint64_t)nlen {
    for (uint64_t i = 0; i + nlen <= hlen; i++)
        if (memcmp(hay + i, n, nlen) == 0) return (NSInteger)i;
    return -1;
}

+ (uint64_t)textVMAddr:(const unsigned char *)p {
    if (r32(p, 0) != MH_MAGIC_64) return 0;
    uint32_t ncmds = r32(p, 16), off = 32;
    for (uint32_t i = 0; i < ncmds; i++) {
        uint32_t cmd = r32(p, off), sz = r32(p, off + 4);
        if (cmd == 0x19) {
            char seg[17] = {0}; memcpy(seg, p + off + 8, 16);
            if (strcmp(seg, "__TEXT") == 0) return r64(p, off + 24);
        }
        off += sz;
    }
    return 0;
}

// ============ 第 1 刀：静态 patch hasLocalActivationCard ============
+ (BOOL)patchHasLocalActivationCardAtPath:(NSString *)binPath error:(NSError **)error {
    NSData *data = [NSData dataWithContentsOfFile:binPath];
    if (!data) {
        if (error) *error = [NSError errorWithDomain:@"CoreCrack" code:1
            userInfo:@{NSLocalizedDescriptionKey:@"无法读取 Core 二进制"}];
        return NO;
    }
    const unsigned char *p = [data bytes];
    uint64_t len = [data length];
    uint64_t textVM = [self textVMAddr:p];
    if (textVM == 0) {
        if (error) *error = [NSError errorWithDomain:@"CoreCrack" code:8
            userInfo:@{NSLocalizedDescriptionKey:@"非法 Mach-O"}];
        return NO;
    }

    const char *sel = "hasLocalActivationCard";
    NSInteger selOff = [self findBytes:p hayLen:len
                               needle:(const unsigned char *)sel needleLen:strlen(sel)];
    if (selOff < 0) {
        if (error) *error = [NSError errorWithDomain:@"CoreCrack" code:2
            userInfo:@{NSLocalizedDescriptionKey:@"未找到 selector"}];
        return NO;
    }
    uint64_t selVM = textVM + (uint64_t)selOff; // __TEXT fileoff==0

    // 扫 relative method list 找引用该 selector 的 entry -> IMP
    uint64_t baseVM = 0x10034C560;
    uint64_t baseOff = baseVM - textVM;
    if (baseOff + 64 > len) {
        if (error) *error = [NSError errorWithDomain:@"CoreCrack" code:3
            userInfo:@{NSLocalizedDescriptionKey:@"method list 越界"}];
        return NO;
    }
    uint32_t flags = r32(p, (uint32_t)baseOff);
    uint32_t count = r32(p, (uint32_t)baseOff + 4);
    BOOL small = (flags & 0x80000000) != 0;
    uint64_t patchOff = 0; BOOL found = NO;

    if (small) {
        for (uint32_t m = 0; m < count; m++) {
            uint32_t eo = (uint32_t)baseOff + 8 + m * 12;
            int32_t nameRel; memcpy(&nameRel, p + eo, 4);
            int32_t impRel;  memcpy(&impRel, p + eo + 8, 4);
            if ((baseVM + (int64_t)nameRel) == selVM) {
                patchOff = (baseVM + (int64_t)impRel) - textVM;
                found = YES; break;
            }
        }
    }
    if (!found) {
        if (error) *error = [NSError errorWithDomain:@"CoreCrack" code:4
            userInfo:@{NSLocalizedDescriptionKey:@"未能定位 IMP（relative list）"}];
        return NO;
    }

    unsigned char patch[] = {0x20,0x00,0x80,0x52,0xC0,0x03,0x5F,0xD6};
    if (patchOff + 8 > len) {
        if (error) *error = [NSError errorWithDomain:@"CoreCrack" code:5
            userInfo:@{NSLocalizedDescriptionKey:@"patch 越界"}];
        return NO;
    }
    NSMutableData *nd = [data mutableCopy];
    [nd replaceBytesInRange:NSMakeRange((NSUInteger)patchOff, 8) withBytes:patch];
    if (![nd writeToFile:binPath atomically:YES]) {
        if (error) *error = [NSError errorWithDomain:@"CoreCrack" code:6
            userInfo:@{NSLocalizedDescriptionKey:@"写回失败"}];
        return NO;
    }
    return YES;
}

// ============ 第 2/3 刀：运行时替换 IMP ============
// 这三个替换函数（C 函数指针）在运行时代替原实现。

static BOOL fake_hasLocalActivationCard(id self, SEL _cmd) {
    return YES;
}

static void fake_createOrRefreshSession(id self, SEL _cmd, id card, void(^completion)(NSString *, NSError *)) {
    if (completion) completion(@"FAKE_TOKEN_CRACKED", nil);
}

static void fake_finishActivation(id self, SEL _cmd, id card, id pending, id progress, void(^completion)(BOOL, NSError *)) {
    if (completion) completion(YES, nil);
}

+ (NSDictionary *)crackRuntime {
    NSMutableDictionary *r = [NSMutableDictionary dictionary];

    // 逐类查找并替换
    NSArray *clsCandidates = @[@"PPMTActivationService", @"PPMTRewardsAPI"];

    IMP fake1 = (IMP)fake_hasLocalActivationCard;
    IMP fake2 = (IMP)fake_createOrRefreshSession;
    IMP fake3 = (IMP)fake_finishActivation;

    BOOL h1 = NO, h2 = NO, h3 = NO;

    for (NSString *cname in clsCandidates) {
        Class cls = NSClassFromString(cname);
        if (!cls) continue;

        // 刀1
        SEL s1 = NSSelectorFromString(@"hasLocalActivationCard");
        if (!h1 && [cls instancesRespondToSelector:s1]) {
            Method m = class_getInstanceMethod(cls, s1);
            method_setImplementation(m, fake1);
            h1 = YES;
        }
        // 刀2
        SEL s2 = NSSelectorFromString(@"createOrRefreshSessionWithCard:completion:");
        if (!h2 && [cls instancesRespondToSelector:s2]) {
            Method m = class_getInstanceMethod(cls, s2);
            method_setImplementation(m, fake2);
            h2 = YES;
        }
        // 刀3
        SEL s3 = NSSelectorFromString(@"finishActivationWithCard:pending:progress:completion:");
        if (!h3 && [cls instancesRespondToSelector:s3]) {
            Method m = class_getInstanceMethod(cls, s3);
            method_setImplementation(m, fake3);
            h3 = YES;
        }
    }

    r[@"hasLocalActivationCard"] = @(h1);
    r[@"createOrRefreshSession"] = @(h2);
    r[@"finishActivation"] = @(h3);
    return r;
}

// ============ 三连主入口 ============
+ (NSDictionary *)crackAllAtPath:(NSString *)binPath error:(NSError **)error {
    NSMutableDictionary *res = [NSMutableDictionary dictionary];

    // 第 1 刀：静态 patch（永久）
    BOOL p1 = [self patchHasLocalActivationCardAtPath:binPath error:error];
    res[@"static_hasLocalActivationCard"] = @(p1);

    // 第 2/3 刀：运行时 hook（需本工具与 Core 同进程，或注入 dylib）
    // 说明：静态二进制里单独 patch 带 block 的方法是脆弱的，
    //      正确做法是注入 dylib 后调用 crackRuntime。
    //      这里返回一个说明，实际运行时机在注入后。
    res[@"runtime_hook_note"] = @"第2/3刀建议用 CoreCrack.js(Frida) 或注入 dylib 调用 crackRuntime";

    return res;
}

// ============ 注入激活状态 ============
// 往 Core 的共享偏好 suite（com.ppmt.sharedstate.manager）写入激活字段，
// 让 Core 启动时读到"已激活"状态，跳过卡密框。
// 采用多候选字段策略：一次写入多个可能的键，覆盖 Core 可能读取的所有 key。
+ (NSDictionary *)injectActivationState {
    NSMutableDictionary *res = [NSMutableDictionary dictionary];

    NSUserDefaults *suite = [[NSUserDefaults alloc] initWithSuiteName:@"com.ppmt.sharedstate.manager"];
    if (!suite) {
        res[@"result"] = @"❌ 无法打开共享偏好 suite";
        return res;
    }

    // 读取当前状态（供诊断）
    NSDictionary *existing = [suite dictionaryRepresentation];
    res[@"现有键"] = [existing.allKeys componentsJoinedByString:@", "] ?: @"(空)";

    // —— 候选激活字段（多写几个，覆盖可能读取的 key）——
    // 1. storedToken：存储"激活 token"（最常见的会话令牌键）
    [suite setObject:@"CRACKED_FAKE_TOKEN_1234567890" forKey:@"storedToken"];
    // 2. ppmt_stored_card_key：存储卡密
    [suite setObject:@"CRACKED-CARD-KEY" forKey:@"ppmt_stored_card_key"];
    // 3. 可能的布尔激活标志
    [suite setBool:YES forKey:@"activated"];
    [suite setBool:YES forKey:@"hasLocalActivationCard"];
    [suite setBool:YES forKey:@"isActivated"];
    // 4. 稳定默认值种子标记（让 Core 认为已初始化）
    [suite setBool:YES forKey:@"PPMTStableDefaultsSeededV1"];

    [suite synchronize];

    res[@"result"] = @"✅ 已尝试写入激活字段";
    res[@"suite"] = @"com.ppmt.sharedstate.manager";
    res[@"写入字段"] = @"storedToken / ppmt_stored_card_key / activated / hasLocalActivationCard / isActivated / PPMTStableDefaultsSeededV1";

    return res;
}

// ============ 重签名 ============
+ (BOOL)resignBinaryAtPath:(NSString *)binPath error:(NSError **)error {
    NSString *dir = [binPath stringByDeletingLastPathComponent];
    NSString *ldidPath = [dir stringByAppendingPathComponent:@"ldid"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:ldidPath]) {
        ldidPath = @"/usr/bin/ldid";
    }
    pid_t pid;
    char *args[] = { (char *)[ldidPath UTF8String], (char *)"-S",
                     (char *)[binPath UTF8String], NULL };
    int ret = posix_spawn(&pid, [ldidPath UTF8String], NULL, NULL, args, environ);
    if (ret == 0) { int st; waitpid(pid, &st, 0); return YES; }
    if (error) *error = [NSError errorWithDomain:@"CoreCrack" code:7
        userInfo:@{NSLocalizedDescriptionKey:@"ldid 重签名失败"}];
    return NO;
}

@end