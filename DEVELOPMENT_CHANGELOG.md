# 开发修改日志

供 DeepSeek Harness（DSH）与 Codex 协作时记录项目变更。每次修改请在文件顶部追加一条，注明日期、修改者、提交号（若已提交）、涉及文件、行为变化，以及是否构建/测试和生成了什么安装包。不要把未验证的结果写成已完成。

### IPA 归档约定

- 每次应用代码修改都递增市场版本和构建号，生成新的未签名 IPA；用户自行完成设备安装测试。
- 最新 IPA 保存在 `dist/` 根目录。新版本成功生成后，将旧版本移入 `dist/version-backups/`；该目录只保留最新版本之前的 20 个 IPA（历史不足 20 个时全部保留）。

## 2026-11-25 · Codex · v1.8.2（构建号 11）

### 照片浏览与详情

- `ios/SwipeClean/Views/CardPager.swift`：当前照片按可用宽度缩进 28 pt 后计算卡片尺寸，左右各留约 14 pt，避免照片贴屏幕边缘；邻卡列表跳过已加入删除备选的照片。
- `ios/SwipeClean/Views/ReviewScreen.swift`：底部控件拆为独立三段：圆形收藏、较宽的详情胶囊、圆形撤回。详情胶囊显示相对拍摄时间；有 `PHAsset.location` 时异步显示反向地理编码地点，无位置时只显示相对时间。详情面板高度增加至可用高度的约 82%。
- `ios/SwipeClean/Views/AssetInfoPanel.swift`：详情面板增加相对时间和完整拍摄时间的醒目标题，并保留照片类型、分辨率、文件名/大小、相机 EXIF 参数及可用的 GPS 地图信息。

### 删除备选与批量选择

- `ios/SwipeClean/Services/ReviewEngine.swift`：新增 `batchCandidates` 保存本轮批量面板的全部候选；批量删除 `bin` 仅表示当前勾选项。左右返回会略过仍在 `bin` 中的照片；撤回按钮仍负责恢复最近加入备选的照片。
- `ios/SwipeClean/Views/BatchSheet.swift`：列表改为显示 `batchCandidates`。取消勾选只从待删除 `bin` 移除，照片仍留在本轮列表，可重新勾选；确认后仅删除勾选项，未勾选项继续保留为已浏览内容。

### 验证状态

- 已运行 `git diff --check`，通过。
- 提交 `089ab42` 已推送；GitHub Actions run #23 构建成功。
- 新包 `dist/SwipeClean-1.8.2-unsigned.ipa`：未签名 arm64 IPA，用户负责安装测试。
- 本次根据用户要求整理 `dist/`：11 个旧 IPA 全部保存在 `dist/version-backups/`（含重复版本名的旧 1.8.0 包）；清除原有子目录。最新的 1.8.2 包位于 `dist/` 根目录。

## 2026-11-25 · Codex · v1.8.3（构建号 12）

- `ios/SwipeClean/Views/ReviewScreen.swift`：将顶部模式胶囊替换为浏览进度条；底部收藏、详情、撤回控件缩至 44 pt 高度。详情不再作为独立圆角面板呈现，改为全屏照片模糊背景覆盖。
- `ios/SwipeClean/Views/AssetInfoPanel.swift`：使用当前照片的高分辨率图像铺满背景并模糊，元数据内容浮在其上。
- `ios/SwipeClean/Services/ReviewEngine.swift`、`ios/SwipeClean/Views/CardPager.swift`：翻页目标和左右邻卡都按删除备选过滤，并以相邻可浏览照片计算动画位置，避免短暂闪过、卡顿或向前翻页再次出现。
- 市场版本/构建号已升至 `1.8.3 (12)`；构建与 IPA 归档结果待记录。

## 2026-11-25 · Codex · `60b7e91`

- `ios/SwipeClean/Views/HomeView.swift`：iOS 26 及以上使用系统 `TabView` 底栏，交由系统 Liquid Glass 处理玻璃外观偏好与辅助功能设置；iOS 16–25 保留自定义底栏。此前自定义选中胶囊留有内缩，旧系统分支改为覆盖完整标签区域。
- `ios/SwipeClean/Services/AppModel.swift`：`HomeTab` 显式遵循 `Hashable`，用于 `TabView` 的 selection/tag。
- `ios/project.yml`、`ios/SwipeClean/Views/SettingsSheet.swift`：市场版本更新为 `1.8.1`，构建号更新为 `10`，同步设置页版本显示。
- 云端 macOS 构建成功，Actions run #22；产物为未签名 `SwipeClean-1.8.1-unsigned.ipa`，已下载到 `dist/SwipeClean-1.8.1/`。仅验证 IPA 包含单个 App、arm64 可执行文件且未签名；用户负责安装测试。

## 2026-11-25 · Codex · `993eba0`（随后被系统底栏方案替代）

- `ios/SwipeClean/Views/HomeView.swift`：将自定义标签栏底板改为项目的 Liquid Glass 辅助效果，iOS 26+ 使用 `glassEffect`，较旧系统回退到 Material。
- 该实现仍使用自绘玻璃导航。后续 `60b7e91` 在 iOS 26+ 改用系统 `TabView`，是当前生效方案。
- 云端构建 run #21 成功；该包早于 `1.8.1` 和本次未提交交互调整，不应作为当前源码安装包。
