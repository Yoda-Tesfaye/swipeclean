# SwipeClean · 滑动清理

一个用原生 SwiftUI + PhotoKit 写的 iOS 相册清理 App：像刷卡片一样浏览相册，上划把内容加入删除备选，每浏览 30 项确认一次，一直刷到相册末尾。

> 参考产品：Linger – Photo Review Clean。本仓库是从零实现的独立工程，不包含任何第三方 SDK、账号体系或网络请求，所有照片只在本机处理。

## 交互

| 操作 | 结果 |
| --- | --- |
| 左右滑动 | 上一张 / 下一张（照片与视频混排，按拍摄时间从新到旧） |
| 上划 | 把当前内容加入删除备选，并自动前进 |
| 下划 | 撤销最近一次加入备选的内容，回到那一张 |
| 点击画面 | 显示 / 隐藏上下操作栏 |
| 顶部垃圾桶 | 打开备选区，可逐项移出或一次性删除 |
| 每浏览 30 项 | 若备选区非空，弹出批次确认：网格预览 + 「跳过，继续下一组」/「确认删除」 |

细节：

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
    App/                      # @main、根视图
    Services/                 # ReviewEngine（状态机）、ImageStore（图片缓存）
    Views/                    # 卡片、手势 pager、批次弹窗、备选区、完成页
    Support/                  # 主题、触感反馈
    Assets.xcassets/          # AppIcon（脚本生成）、启动色
scripts/
  make_icons.py               # 重新生成图标
  win-build-ipa.ps1           # Windows 上一键云编译并下载 ipa
.github/workflows/
  build-ios-ipa.yml           # macOS runner 编译未签名 ipa
```

## 构建 ipa

### 方式 A：Windows 一键（需要 GitHub PAT）

1. GitHub → Settings → Developer settings → **Personal access tokens (classic)** → 生成，勾选 `repo` + `workflow`。
2. 执行：

```powershell
$env:GH_PAT = 'ghp_你的token'
pwsh -File scripts\win-build-ipa.ps1
```

脚本会创建（或复用）私有仓库 `swipeclean`、推送代码、等待 macOS runner 编译、把 ipa 解压到 `dist/`。失败时会自动拉取构建日志尾部。

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
