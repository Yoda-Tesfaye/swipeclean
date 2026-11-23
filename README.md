# SwipeClean · 滑动清理

一个用原生 SwiftUI + PhotoKit 写的 iOS 相册清理 App：像刷卡片一样浏览相册，上划把内容加入删除备选，每浏览 30 项确认一次，一直刷到相册末尾。

> 参考产品：Linger – Photo Review Clean。本仓库是从零实现的独立工程，不包含任何第三方 SDK、账号体系或网络请求，所有照片只在本机处理。

## 交互

主界面分三个 tab：**照片 / 视频 / 统计**。照片和视频各自一套卡片堆，互不干扰。

| 操作 | 结果 |
| --- | --- |
| 轻点主界面的卡片堆 | 进入该类型的全屏浏览 |
| 左右滑动 | 上一张 / 下一张（照片与视频各自独立） |
| 上划 | 把当前内容加入删除备选，卡片**只沿 Y 轴**飞出，并自动前进 |
| 下划 | 撤销最近一次加入备选的内容，回到那一张 |
| 点击画面 | 显示 / 隐藏上下操作栏 |
| 顶部胶囊 | 显示剩余数量，点开可调整「每组数量」或重置浏览记录 |
| 每浏览 N 项 | 若备选区非空，弹出「回顾完毕」：网格预览 + 「放弃，再来一组」/「确认删除」 |
| 统计 tab | 查看/删除/待删除计数、重置浏览记录、设置入口 |

细节：

- **原比例显示**：全屏浏览时卡片按 `pixelWidth/pixelHeight` 定尺寸，照片不再有上下黑边；卡片底下垫的是当前照片的模糊环境背景（液态玻璃的基底），卡片内不显示日期/EXIF。
- **液态玻璃风格**：顶部/底部控制条、标签栏、胶囊与圆形按钮都用 `ultraThinMaterial` + 高光描边 + 浮层阴影实现，iOS 16 及以上可用（未调用 iOS 26 才有的 `glassEffect`，因为构建机是 Xcode 16.4 / iOS 18.5 SDK）。
- **随机顺序、不重复**：每次进入按未浏览内容随机排列；浏览过的照片/视频会写入本地 `viewed.json`，下次不再出现。想再清一遍？统计页或设置里的「重置浏览记录」会重新洗牌。
- **每组数量可调**：默认 30，可在 10/15/20/30/50 之间按照片、视频分别设置。
- 视频会自动静音循环播放（和系统相册一致），缩略图角落显示时长。
- 图片走 `PHCachingImageManager` + `NSCache`，并提前预热前后各 1～2 页，滑动不白屏。
- 删除走 `PHAssetChangeRequest.deleteAssets`，内容进入系统「最近删除」，30 天内可恢复。
- 每批删除完成后重新计算游标，浏览不会跳页；一直浏览到相册末尾进入统计页，可重新扫描。

## 技术栈

- Swift 5 / SwiftUI，最低 iOS 16.0，仅 iPhone 竖屏
- PhotoKit（授权、缩略图、视频 AVAsset、删除）
- AVFoundation（视频播放）
- 零第三方依赖，工程由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 从 `ios/project.yml` 生成

## 目录

```
ios/
  project.yml                 # XcodeGen 工程定义
  Support/Info.plist          # 权限文案、启动屏、竖屏等
  SwipeClean/
    App/                      # @main、根视图（权限门）
    Services/                 # AppModel、ReviewEngine、浏览记录、设置、图片缓存
    Views/                    # 卡片堆、全屏浏览、批次弹窗、统计/设置
    Support/                  # 主题、触感反馈
    Assets.xcassets/          # AppIcon（脚本生成）、启动色
scripts/
  make_icons.py               # 重新生成图标
  publish-and-build.ps1       # Windows 一键：建仓库、推送、云编译、下载 ipa
  verify_ipa.py               # 校验 ipa 结构 / 架构 / 嵌入字符串
.github/workflows/
  build-ios-ipa.yml           # macOS runner 编译未签名 ipa
```

## 构建 ipa

`.ipa` 里的可执行文件必须由 Xcode 编译，Windows 上没有 iOS 工具链，所以编译放在 GitHub 免费的 macOS runner 上完成（一次约 1–3 分钟）。

### 方式 A：Windows 一键（不需要在聊天里贴 token）

首次先让 Git Credential Manager 登录 GitHub（浏览器设备码，一次性）：

```powershell
git-credential-manager github login --device
```

之后每次一条命令：创建/复用私有仓库 → 推送 → 等待 macOS 编译 → 把 ipa 解压到 `dist/`：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\publish-and-build.ps1
```

脚本优先使用 `$env:GH_PAT`（classic PAT，`repo` + `workflow` 权限），没有设置时自动复用 Git Credential Manager 里已存的账号。

### 方式 B：GitHub 网页

推送到任意仓库的 `main` 分支后，**Actions → Build unsigned iOS IPA** 自动运行；也可以手动 `Run workflow`。完成后在 run 页面底部下载 `SwipeClean-ipa` artifact。

### 方式 C：有 Mac

```bash
brew install xcodegen
cd ios
xcodegen generate
xcodebuild -project SwipeClean.xcodeproj -scheme SwipeClean \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build
mkdir -p Payload && cp -R build/Build/Products/Release-iphoneos/SwipeClean.app Payload/
zip -qry SwipeClean-unsigned.ipa Payload
```

产物是**未签名 ipa**，不能直接 AirDrop 安装，需要用下面的工具用自己的 Apple ID 重签。

### 验证产物

```powershell
python scripts\verify_ipa.py dist\SwipeClean-1.0.0-unsigned.ipa
```

检查项：单 App 结构、Bundle ID / 版本 / 最低系统、arm64 Mach-O、二进制里是否真的编进了本工程的中文界面串、以及是否确实未签名（无 `_CodeSignature`，留给侧载工具重签）。

## 安装到 iPhone（免费 Apple ID 侧载）

1. 安装 [Sideloadly](https://sideloadly.io/)；Windows 还需装**非 Microsoft Store 版 iTunes**（提供 Apple 驱动）。
2. 数据线连接 iPhone，点「信任此电脑」。
3. 把 `dist/SwipeClean-1.0.0-unsigned.ipa` 拖进 Sideloadly，填 Apple ID，点 **Start**（开了双重认证就用 App 专用密码）。
4. iPhone：设置 → 通用 → VPN 与设备管理 → 开发者 App → 信任你的 Apple ID。
5. iOS 16+：设置 → 隐私与安全性 → **开发者模式** → 打开并重启。
6. 首次启动允许相册访问（建议「完全访问」）。

免费账号签名 7 天有效，到期重新拖一次即可；同时最多 3 个自签 App。

## 已知限制

- 删除时系统会再弹一次「允许删除 N 项？」——这是 iOS 对第三方 App 的强制确认，无法跳过。
- 「有限访问」模式下只能看到你授权的那部分照片。
- 免费签名 7 天过期；上架 App Store 需要付费开发者账号。
- 视频仅做浏览与删除，不做转码/压缩。

## License

MIT

