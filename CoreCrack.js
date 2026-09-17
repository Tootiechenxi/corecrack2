// ============================================================
//  CoreCrack.js — 巨魔Core-SET「一键三连」运行时破解 (frida)
//
//  三连：
//    1. hasLocalActivationCard  -> 永远返回 true（本地激活卡判定）
//    2. createOrRefreshSessionWithCard:completion: -> 伪造成功 token（绕过服务端）
//    3. finishActivationWithCard:... -> 强制成功分支（忽略设备绑定错误码）
//
//  环境：TrollStore（巨魔）设备 + Frida
//  用法：frida -U -f com.apple.manager -l CoreCrack.js --no-pause
//
//  已核对新版类名/selector 全部匹配。
// ============================================================

'use strict';

function log(m) { console.log('[CoreCrack] ' + m); }

// —— 三连 hook ——

// 1. hasLocalActivationCard -> 返回 true
function hook1() {
    var target = null;
    var sel = 'hasLocalActivationCard';
    // 方法可能在 PPMTActivationService 或 PPMTRewardsAPI 上，逐个找
    ['PPMTActivationService', 'PPMTRewardsAPI'].forEach(function (cn) {
        if (target) return;
        var cls = ObjC.classes[cn];
        if (cls && cls[sel]) target = cls[sel];
    });
    if (!target) { log('⚠️ [1/3] 未找到 ' + sel); return; }

    var impl = target.implementation;
    Interceptor.replace(impl, new NativeCallback(function () {
        return 0x1; // BOOL YES
    }, 'bool', []));
    log('✅ [1/3] ' + sel + ' → 永远 YES');
}

// 2. createOrRefreshSessionWithCard:completion: -> 伪造成功 token
function hook2() {
    var target = null;
    var sel = 'createOrRefreshSessionWithCard:completion:';
    ['PPMTRewardsAPI', 'PPMTActivationService'].forEach(function (cn) {
        if (target) return;
        var cls = ObjC.classes[cn];
        if (cls && cls[sel]) target = cls[sel];
    });
    if (!target) { log('⚠️ [2/3] 未找到 ' + sel); return; }

    var impl = target.implementation;
    Interceptor.replace(impl, new NativeCallback(function (self, _cmd, card, completion) {
        log('[2/3] 伪造会话成功（跳过服务端）');
        if (completion && !completion.isNull()) {
            // block 签名: void(^)(NSString *token, NSError *err)
            var callBlock = new NativeFunction(completion, 'void',
                ['pointer', 'pointer']);
            var token = ObjC.classes.NSString.stringWithString_('FAKE_TOKEN_CRACKED');
            callBlock(token, null);
        }
    }, 'void', ['pointer', 'pointer', 'pointer', 'pointer']));
    log('✅ [2/3] ' + sel + ' → 伪造成功 token');
}

// 3. finishActivationWithCard:pending:progress:completion: -> 强制成功
function hook3() {
    var target = null;
    var sel = 'finishActivationWithCard:pending:progress:completion:';
    ['PPMTActivationService', 'PPMTRewardsAPI'].forEach(function (cn) {
        if (target) return;
        var cls = ObjC.classes[cn];
        if (cls && cls[sel]) target = cls[sel];
    });
    if (!target) { log('⚠️ [3/3] 未找到 ' + sel); return; }

    var impl = target.implementation;
    Interceptor.replace(impl, new NativeCallback(function (self, _cmd, card, pending, progress, completion) {
        log('[3/3] 强制激活成功（忽略设备绑定错误码）');
        if (completion && !completion.isNull()) {
            // block 签名: void(^)(BOOL success, NSError *err)
            var callBlock = new NativeFunction(completion, 'void',
                ['bool', 'pointer']);
            callBlock(0x1, null);
        }
    }, 'void', ['pointer', 'pointer', 'pointer', 'pointer', 'pointer', 'pointer']));
    log('✅ [3/3] ' + sel + ' → 强制成功');
}

// 主流程
function main() {
    log('============================================');
    log(' CoreCrack — 三连破解开始');
    log('============================================');
    hook1();
    hook2();
    hook3();
    log('============================================');
    log(' 三连 hook 完成。请在手机上操作 Core.app 验证。');
    log('============================================');
}

// 等待 ObjC runtime 加载
if (ObjC.available) {
    main();
} else {
    log('等待 ObjC runtime ...');
    var t = setInterval(function () {
        if (ObjC.available) { clearInterval(t); main(); }
    }, 100);
}