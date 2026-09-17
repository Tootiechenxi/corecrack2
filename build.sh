#!/bin/bash
# ============================================================
#  build.sh — CoreCrack 一键三连 完整成品打包脚本
#
#  产出：
#    1. CoreCrack.ipa          静态 patch 工具（装进 TrollStore）
#    2. CoreCrack.js            Frida 一键三连 hook（推荐）
#    3. crack_package.zip      完整成品包（含教程）
#
#  环境：macOS + Xcode 命令行工具（xcrun/clang）
# ============================================================

set -e

SDK_PATH=$(xcrun --sdk iphoneos --show-sdk-path)
ARCH=arm64
MIN_IOS=14.0
OUT_DIR="crack_package"

echo "=============================================="
echo " CoreCrack 一键三连 打包开始"
echo "=============================================="
echo "[*] SDK: $SDK_PATH"
echo "[*] 架构: $ARCH  最低 iOS: $MIN_IOS"

# ---------- 1. 编译 Objective-C ----------
echo ""
echo "[1/5] 编译 CoreCrack.m（破解核心）..."
clang -arch $ARCH -isysroot $SDK_PATH \
      -mios-version-min=$MIN_IOS \
      -fobjc-arc \
      -framework Foundation \
      -framework UIKit \
      -c CoreCrack.m -o CoreCrackCore.o

echo "[2/5] 编译 main.m（界面入口）..."
clang -arch $ARCH -isysroot $SDK_PATH \
      -mios-version-min=$MIN_IOS \
      -fobjc-arc \
      -framework Foundation \
      -framework UIKit \
      -c main.m -o main.o

# ---------- 2. 链接 ----------
echo "[3/5] 链接 ..."
clang -arch $ARCH -isysroot $SDK_PATH \
      -mios-version-min=$MIN_IOS \
      -framework Foundation -framework UIKit \
      main.o CoreCrackCore.o \
      -o CoreCrack

echo "  ✅ 编译链接完成：CoreCrack ($(stat -f%z CoreCrack) 字节)"

# ---------- 3. 打包 .app ----------
echo "[4/5] 打包 .app 与 ipa ..."
APP_DIR="Payload/CoreCrack.app"
rm -rf Payload
mkdir -p "$APP_DIR"
cp CoreCrack "$APP_DIR/"
cp Info.plist "$APP_DIR/"

# ldid 假签名（可选，TrollStore 通常接受未签名）
if command -v ldid >/dev/null 2>&1; then
    ldid -S "$APP_DIR/CoreCrack" 2>/dev/null && echo "  ✅ ldid 假签名完成" || echo "  ⚠️ ldid 签名失败（可忽略）"
else
    echo "  ⚠️ 未找到 ldid，TrollStore 通常可直接侧载未签名 ipa"
fi

zip -qr CoreCrack.ipa Payload/
echo "  ✅ 产出 CoreCrack.ipa"

# ---------- 4. 组装成品包 ----------
echo "[5/5] 组装完整成品包 ..."
rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

cp CoreCrack.ipa  "$OUT_DIR/"
cp CoreCrack.js   "$OUT_DIR/"
cp README.md      "$OUT_DIR/使用教程.md"

# 附带一个中文速查说明
cat > "$OUT_DIR/README_速查.txt" << 'EOF'
===============================
 CoreCrack 一键三连 速查
===============================

【成品一】CoreCrack.ipa
  静态 patch 工具，TrollStore 侧载后点"①静态三连"，
  可 patch hasLocalActivationCard 并 ldid 重签。

【成品二】CoreCrack.js  （推荐先试）
  Frida 运行时三连 hook，跳过三重校验：
    ① 本地激活卡 → YES
    ② 服务端验卡 → 伪造 token
    ③ 设备绑定 → 强制成功

  用法：
    pip install frida-tools
    frida -U -f com.apple.manager -l CoreCrack.js --no-pause

【注意】
  - 目标 Bundle ID: com.apple.manager（见 Core 的 Info.plist）
  - 这是针对你自己的程序/设备做安全研究测试。
EOF

# 打包
zip -qr crack_package.zip "$OUT_DIR"

echo ""
echo "=============================================="
echo " ✅ 全部完成！产物："
echo "    - CoreCrack.ipa         (静态 patch 工具)"
echo "    - CoreCrack.js          (Frida 三连 hook)"
echo "    - crack_package.zip     (完整成品包)"
echo "=============================================="
echo "  安装 CoreCrack.ipa：TrollStore -> Install IPA"
echo "  运行三连 hook：frida -U -f com.apple.manager -l CoreCrack.js --no-pause"
echo "=============================================="