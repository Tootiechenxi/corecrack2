# 巨魔Core-SET「一键三连」彻底破解 — 完整方案

> 三重校验全部绕过：
> 1. 本地激活卡判定（hasLocalActivationCard）
> 2. 服务端卡密校验（createOrRefreshSessionWithCard）
> 3. 设备绑定（DEVICE_CARD_MISMATCH / LOCAL_CARD_REQUIRED）

---

## 一、三刀分别砍在哪（逆向结论）

| # | 校验点 | 类/方法 | 触发时机 | 砍法 |
|---|---|---|---|---|
| 1 | 本地激活卡 | `PPMTActivationService.hasLocalActivationCard` | App 启动判断 | 返回 YES |
| 2 | 服务端验卡 | `PPMTRewardsAPI.createOrRefreshSessionWithCard:completion:` | 激活时请求 `order.klpjwycb.xyz` | 伪造成功 token |
| 3 | 设备绑定 | `finishActivationWithCard:...` 的失败分支 | 服务端回 `DEVICE_CARD_MISMATCH` | 强制成功 |

## 二、两种成品（选一个）

### 方案 A：运行时 Hook（推荐，最稳）

文件：`CoreCrack.js`

**原理**：用 Frida 在运行时拦截三个方法，不改二进制、不碰签名。

**优点**：稳定，不担心签名，随时可逆。
**缺点**：每次启动都要跑 Frida。

**用法**：
```bash
# 1. 手机装好 Frida（Sileo/Cydia 搜 frida-server）
# 2. Mac/PC 装 frida-tools
pip install frida-tools
# 3. 附加并注入
frida -U -f com.apple.manager -l CoreCrack.js --no-pause
```

---

### 方案 B：静态 Patch（一劳永逸，改完永久生效）

文件：`CoreCrack.h/.m`（已升级为三连版）

**原理**：直接把三个方法的 arm64 字节覆盖成"假实现"。

**优点**：改一次，永久生效，不用每次跑工具。
**缺点**：改完签名失效，必须 `ldid -S` 重签；且需精确锚定 IMP 偏移。

**三处 patch 的字节**：

```asm
; 1. hasLocalActivationCard -> mov w0,#1; ret
20 00 80 52  C0 03 5F D6

; 2/3. 成功回调（伪代码），实际需根据方法签名构造
;     createOrRefreshSession: 直接调 completion(token, nil)
;     finishActivation: 直接调 completion(YES, nil)
```

---

## 三、静态 patch 的精确偏移（逆向实测）

> 关键 selector / IMP 地址（来自 Mach-O 静态逆向）：

| 目标 | 类型 | 地址 |
|---|---|---|
| `hasLocalActivationCard` selector | methname | 0x1003D1BF1 (file 0x3D1BF1) |
| `PPMTActivationService` baseMethods | methlist | 0x10034C560 |
| IMP 候选 A（实例方法） | __TEXT | 0x10005B018 |
| IMP 候选 B（实例方法） | __TEXT | 0x100055988 |
| `createOrRefreshSessionWithCard:` stub | __objc_stubs | 0x1003443C0 |
| `finishActivationWithCard:` stub | __objc_stubs | 0x1003450E0 |

> ⚠️ 说明：iOS 15+ 的 relative method list + chained selector 格式，
>   IMP 的「方法名→地址」精确对应需在真机用 Frida 二次锚定。
>   这也是为什么**推荐方案 A（Frida）**——它用 selector 名直接 hook，
>   不用和 chained pointer 死磕。

---

## 四、推荐落地顺序

1. **先用方案 A（frida）** 快速验证三刀逻辑对不对
2. 验证 OK 后，用 `frida-trace -m '...'` 拿到三个方法**真正的 IMP 地址**
3. 把 IMP 地址回填进方案 B（CoreCrack.m），做静态 patch
4. `ldid -S` 重签，永久生效

---

## 五、关键结论修正（重要）

逆向过程中确认：

- **`DEVICE_CARD_MISMATCH` 和 `LOCAL_CARD_REQUIRED` 是服务端返回的错误码**，不是本地 `deviceMask` 比对结果。
- 设备绑定判定**在服务端**（`order.klpjwycb.xyz`），客户端把 `device_id` + `bundle_id` + `deviceMask` 发上去，服务端比对后回错误码。
- 因此**第三刀的本质是"忽略服务端错误码，强制走成功分支"**，而不是 patch 本地比对。

---

## 六、文件清单（更新后）

```
CoreCrack/
├── CoreCrack.js     ← [NEW] 方案A：Frida 一键三连 hook（推荐先试这个）
├── CoreCrack.h      ← 方案B：静态 patch 头文件
├── CoreCrack.m      ← 方案B：静态 patch 实现（三连版）
├── main.m           ← 界面 + 一键按钮
├── Info.plist
├── build.sh         ← 编译脚本
└── README.md        ← 本教程
```