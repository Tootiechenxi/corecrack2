// ============================================================
//  CoreCrack.h — 巨魔Core-SET 一键三连破解（手机端）
//
//  三刀：
//    1. hasLocalActivationCard -> 永远 YES（本地激活卡）
//    2. createOrRefreshSessionWithCard:completion: -> 跳过服务端
//    3. finishActivationWithCard:... -> 强制成功（绕过设备绑定错误码）
//
//  环境：TrollStore（巨魔）侧载运行。
// ============================================================

#import <Foundation/Foundation.h>

@interface CoreCrack : NSObject

// 定位 Core 二进制
+ (NSString *)locateCoreBinary;

// 三连 patch（返回每刀的成败）
+ (NSDictionary *)crackAllAtPath:(NSString *)binPath error:(NSError **)error;

// 单刀：patch hasLocalActivationCard 返回 YES
+ (BOOL)patchHasLocalActivationCardAtPath:(NSString *)binPath error:(NSError **)error;

// 运行时三连 hook（替换三方法 IMP，返回各刀成败）
+ (NSDictionary *)crackRuntime;

// 注入激活状态：往 com.ppmt.sharedstate.manager 共享偏好写入激活字段
+ (NSDictionary *)injectActivationState;

// 重签名（ldid）
+ (BOOL)resignBinaryAtPath:(NSString *)binPath error:(NSError **)error;

@end