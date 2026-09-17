// ============================================================
//  main.m — CoreCrack 三连破解工具入口（硬编码路径版）
//
//  已写死本机 Core 路径，打开即定位；仍保留输入框兜底。
//  两个按钮：
//    [① 静态三连]  patch hasLocalActivationCard + ldid 重签名
//    [② 运行时 Hook]  替换三方法 IMP（本进程内有效）
// ============================================================

#import <UIKit/UIKit.h>
#import "CoreCrack.h"
#import "HostsCrack.h"
#import "DomainSwap.h"

// 假服务器地址（你的云服务器）
#define kFakeServerIP   @"165.154.3.167"
#define kTargetDomain   @"order.klpjwycb.xyz"
// 等长替换目标域名（18 字符，与 klpjwycb 同长）
#define kSwapToDomain   @"order.xidudexi.xyz"

// —— 硬编码路径：你的 Core 实际安装位置（Filza 查到，2026-09-17 更新）——
#define kHardcodedCorePath @"/var/containers/Bundle/Application/E876D8C3-B4F6-416F-850E-D6F71E048313/Core.app/Core"

@interface CrackVC : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *pathField;
@end

@implementation CrackVC

- (NSString *)targetPath {
    NSString *typed = self.pathField.text;
    typed = [typed stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    // 输入框有内容且文件存在 → 用输入框
    if (typed.length > 0 && [[NSFileManager defaultManager] fileExistsAtPath:typed])
        return typed;

    // 1) 先用 CoreCrack 的自动搜索
    NSString *found = [CoreCrack locateCoreBinary];
    if (found) return found;

    // 2) 广泛搜索：多个可能的基础目录
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *bases = @[
        @"/var/containers/Bundle/Application",
        @"/private/var/containers/Bundle/Application",
        @"/var/mobile/Containers/Bundle/Application",
    ];
    for (NSString *base in bases) {
        NSArray *dirs = [fm contentsOfDirectoryAtPath:base error:nil];
        for (NSString *d in dirs) {
            NSString *p = [[base stringByAppendingPathComponent:d]
                           stringByAppendingPathComponent:@"Core.app/Core"];
            if ([fm fileExistsAtPath:p]) return p;
        }
    }

    // 3) 兜底：返回硬编码路径（可能已失效，用来提示）
    return kHardcodedCorePath;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithWhite:0.05 alpha:1.0];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"CoreCrack v5 — 五刀版";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:20];
    title.textAlignment = NSTextAlignmentCenter;
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:title];

    // 路径输入框（预填硬编码路径，可手动改）
    self.pathField = [[UITextField alloc] init];
    self.pathField.text = kHardcodedCorePath;
    self.pathField.textColor = [UIColor whiteColor];
    self.pathField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    self.pathField.font = [UIFont systemFontOfSize:11];
    self.pathField.delegate = self;
    self.pathField.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.pathField];

    UILabel *binLabel = [[UILabel alloc] init];
    binLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    binLabel.font = [UIFont systemFontOfSize:12];
    binLabel.numberOfLines = 0;
    binLabel.translatesAutoresizingMaskIntoConstraints = NO;
    binLabel.text = [NSString stringWithFormat:@"目标：%@", kHardcodedCorePath];
    [self.view addSubview:binLabel];

    UIButton *btnStatic = [UIButton buttonWithType:UIButtonTypeSystem];
    [btnStatic setTitle:@"① 静态三连（patch + 重签）" forState:UIControlStateNormal];
    [btnStatic setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnStatic.backgroundColor = [UIColor colorWithRed:0.9 green:0.25 blue:0.2 alpha:1.0];
    btnStatic.layer.cornerRadius = 10;
    btnStatic.translatesAutoresizingMaskIntoConstraints = NO;
    [btnStatic addTarget:self action:@selector(doStatic) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnStatic];

    UIButton *btnRuntime = [UIButton buttonWithType:UIButtonTypeSystem];
    [btnRuntime setTitle:@"② 运行时三连 Hook" forState:UIControlStateNormal];
    [btnRuntime setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnRuntime.backgroundColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:1.0];
    btnRuntime.layer.cornerRadius = 10;
    btnRuntime.translatesAutoresizingMaskIntoConstraints = NO;
    [btnRuntime addTarget:self action:@selector(doRuntime) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnRuntime];

    UIButton *btnInject = [UIButton buttonWithType:UIButtonTypeSystem];
    [btnInject setTitle:@"③ 注入激活状态（改本地偏好）" forState:UIControlStateNormal];
    [btnInject setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnInject.backgroundColor = [UIColor colorWithRed:0.2 green:0.65 blue:0.35 alpha:1.0];
    btnInject.layer.cornerRadius = 10;
    btnInject.translatesAutoresizingMaskIntoConstraints = NO;
    [btnInject addTarget:self action:@selector(doInject) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnInject];

    UIButton *btnHijack = [UIButton buttonWithType:UIButtonTypeSystem];
    [btnHijack setTitle:@"④ 劫持服务器（改 hosts + 查权限）" forState:UIControlStateNormal];
    [btnHijack setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnHijack.backgroundColor = [UIColor colorWithRed:0.85 green:0.55 blue:0.1 alpha:1.0];
    btnHijack.layer.cornerRadius = 10;
    btnHijack.translatesAutoresizingMaskIntoConstraints = NO;
    [btnHijack addTarget:self action:@selector(doHijack) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnHijack];

    UIButton *btnSwap = [UIButton buttonWithType:UIButtonTypeSystem];
    [btnSwap setTitle:@"⑤ 域名替换（klpjwycb→xidudexi）" forState:UIControlStateNormal];
    [btnSwap setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    btnSwap.backgroundColor = [UIColor colorWithRed:0.55 green:0.2 blue:0.75 alpha:1.0];
    btnSwap.layer.cornerRadius = 10;
    btnSwap.translatesAutoresizingMaskIntoConstraints = NO;
    [btnSwap addTarget:self action:@selector(doSwap) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnSwap];

    UITextView *log = [[UITextView alloc] init];
    log.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    log.textColor = [UIColor colorWithRed:0.7 green:1.0 blue:0.7 alpha:1.0];
    log.font = [UIFont fontWithName:@"Menlo" size:12] ?: [UIFont systemFontOfSize:12];
    log.editable = NO;
    log.tag = 999;
    log.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:log];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [title.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [title.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.pathField.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [self.pathField.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.pathField.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.pathField.heightAnchor constraintEqualToConstant:32],
        [binLabel.topAnchor constraintEqualToAnchor:self.pathField.bottomAnchor constant:6],
        [binLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [binLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        // 按钮区（紧凑排布，确保⑤可见）
        [btnStatic.topAnchor constraintEqualToAnchor:binLabel.bottomAnchor constant:10],
        [btnStatic.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [btnStatic.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [btnStatic.heightAnchor constraintEqualToConstant:44],
        [btnRuntime.topAnchor constraintEqualToAnchor:btnStatic.bottomAnchor constant:8],
        [btnRuntime.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [btnRuntime.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [btnRuntime.heightAnchor constraintEqualToConstant:44],
        [btnInject.topAnchor constraintEqualToAnchor:btnRuntime.bottomAnchor constant:8],
        [btnInject.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [btnInject.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [btnInject.heightAnchor constraintEqualToConstant:44],
        [btnHijack.topAnchor constraintEqualToAnchor:btnInject.bottomAnchor constant:8],
        [btnHijack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [btnHijack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [btnHijack.heightAnchor constraintEqualToConstant:44],
        [btnSwap.topAnchor constraintEqualToAnchor:btnHijack.bottomAnchor constant:8],
        [btnSwap.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [btnSwap.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [btnSwap.heightAnchor constraintEqualToConstant:44],
        // 日志框：占用剩余空间
        [log.topAnchor constraintEqualToAnchor:btnSwap.bottomAnchor constant:10],
        [log.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [log.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [log.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-8],
    ]];
}

- (void)log:(NSString *)m {
    UITextView *tv = [self.view viewWithTag:999];
    tv.text = [NSString stringWithFormat:@"%@%@\n", tv.text ?: @"", m];
    if (tv.contentSize.height > tv.bounds.size.height)
        [tv scrollRangeToVisible:NSMakeRange(tv.text.length - 1, 1)];
}

- (void)doStatic {
    NSString *bin = [self targetPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:bin] == NO) {
        [self log:[NSString stringWithFormat:@"❌ 目标不存在：%@", bin]];
        [self log:@"  请确认路径正确（用 Filza 复查）"];
        return;
    }
    [self log:[NSString stringWithFormat:@"[①静态] 目标：%@", bin]];
    NSError *err = nil;
    [self log:@"[①静态] patch hasLocalActivationCard ..."];
    BOOL ok = [CoreCrack patchHasLocalActivationCardAtPath:bin error:&err];
    if (!ok) { [self log:[NSString stringWithFormat:@"❌ %@", err.localizedDescription]]; return; }
    [self log:@"  ✅ 第一刀完成（本地激活卡 → 永远 YES）"];
    [self log:@"[①静态] ldid 重签名 ..."];
    if ([CoreCrack resignBinaryAtPath:bin error:&err]) {
        [self log:@"  ✅ 重签名完成。重开 Core.app 检查第一刀。"];
    } else {
        [self log:[NSString stringWithFormat:@"  ⚠️ 重签名失败：%@", err.localizedDescription]];
        [self log:@"  （如果 patch 已成功，可在 Filza 里手动 ldid -S 重签）"];
    }
    [self log:@"\n提示：若激活提示仍在，说明卡在服务端，需 Frida 三连。"];
}

- (void)doRuntime {
    [self log:@"[②运行时] 尝试替换三方法 IMP ..."];
    NSDictionary *r = [CoreCrack crackRuntime];
    for (NSString *k in r) {
        [self log:[NSString stringWithFormat:@"  %@  ->  %@", k,
                    ([r[k] boolValue] ? @"✅ 已 hook" : @"❌ 未找到")]];
    }
    [self log:@"\n⚠️ 运行时 hook 仅在本进程有效。"];
    [self log:@"  要 hook Core.app 进程，需 Frida（见 CoreCrack.js）。"];
}

- (void)doInject {
    [self log:@"[③注入] 往 com.ppmt.sharedstate.manager 写入激活字段 ..."];
    NSDictionary *r = [CoreCrack injectActivationState];
    for (NSString *k in r) {
        [self log:[NSString stringWithFormat:@"  %@ = %@", k, r[k]]];
    }
    [self log:@"\n✅ 已尝试注入。现在打开 Core.app 检查是否跳过卡密框。"];
    [self log:@"  若仍卡住，说明字段格式不对，把上方「现有键」发我。"];
}

- (void)doHijack {
    [self log:@"[④劫持] 检查 /etc/hosts 权限 ..."];
    NSDictionary *chk = [HostsCrack checkHostsPermission];
    [self log:[NSString stringWithFormat:@"  可读=%@  可写=%@  已有劫持=%@",
               chk[@"可读"], chk[@"可写"], chk[@"已有劫持条目"]]];

    BOOL writable = [chk[@"可写"] isEqualToString:@"是"];
    if (!writable) {
        [self log:@"  ⚠️ 本 App 无权限写 /etc/hosts（TrollStore 沙盒限制）"];
        [self log:@"  仍需用 Filza(root) 手动改，或者用 DNS 方案。"];
        [self log:[NSString stringWithFormat:@"  要加的内容：%@  %@", kFakeServerIP, kTargetDomain]];
        return;
    }

    [self log:@"[④劫持] 写入 hosts ..."];
    NSDictionary *r = [HostsCrack redirectDomain:kTargetDomain toIP:kFakeServerIP];
    for (NSString *k in r) {
        [self log:[NSString stringWithFormat:@"  %@ = %@", k, r[k]]];
    }
    [self log:@"\n✅ 若显示写入成功，现在打开 Core.app 点「初始化」测试。"];
    [self log:@"  注意：手机需已安装并信任 Caddy 根证书！"];
}

- (void)doSwap {
    NSString *bin = [self targetPath];
    [self log:[NSString stringWithFormat:@"[⑤替换] 目标：%@", bin]];

    if ([[NSFileManager defaultManager] fileExistsAtPath:bin] == NO) {
        [self log:@"❌ 目标不存在。请用 Filza 查 Core.app 的真实路径，"];
        [self log:@"   填到上方输入框，或先点②自动搜索。"];
        return;
    }

    // 先扫描当前有哪些域名
    [self log:@"[⑤替换] 扫描二进制里的域名 ..."];
    NSDictionary *scan = [DomainSwap scanDomains:bin];
    for (NSString *k in scan) {
        [self log:[NSString stringWithFormat:@"  %@ : %@", k, scan[k]]];
    }

    // 执行等长替换
    [self log:@"[⑤替换] 等长替换 order.klpjwycb.xyz -> order.xidudexi.xyz ..."];
    NSDictionary *r = [DomainSwap swapDomainInFile:bin
                                        fromDomain:kTargetDomain
                                          toDomain:kSwapToDomain];
    for (NSString *k in r) {
        [self log:[NSString stringWithFormat:@"  %@ = %@", k, r[k]]];
    }

    // 自动重签名
    [self log:@"[⑤替换] 重签名 ..."];
    NSError *err = nil;
    if ([CoreCrack resignBinaryAtPath:bin error:&err]) {
        [self log:@"  ✅ 重签名成功"];
    } else {
        [self log:[NSString stringWithFormat:@"  ⚠️ 重签名失败：%@", err.localizedDescription]];
    }
    [self log:@"\n完成后打开 Core.app 点「初始化」测试。"];
}

- (BOOL)textFieldShouldReturn:(UITextField *)tf {
    [tf resignFirstResponder];
    return YES;
}

@end

@interface CrackAppDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation CrackAppDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opt {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.rootViewController = [[CrackVC alloc] init];
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil,
                                 NSStringFromClass([CrackAppDelegate class]));
    }
}