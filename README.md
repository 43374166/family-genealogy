# 张氏族谱 · 家族族谱管理系统

以族谱树为核心的家族信息管理系统。当前仓库处于 **Flutter 移动端原型阶段**：
Android 端已经可以运行，iOS 工程已生成；Web、鸿蒙、小程序与 Go 服务端先保留清晰的扩展位置，
暂时不写后端。

> 设计参考：`docs/reference/ui-home.png`、`docs/reference/ui-tree.png`
> 产品规划：`docs/reference/项目开发规划报告.docx`

## 运行预览

以下为 Android 模拟器中的实际运行截图（更多页面见 [docs/screenshots](docs/screenshots/README.md)）：

| 首页 | 族谱树 |
| --- | --- |
| ![首页](docs/screenshots/home.png) | ![族谱树](docs/screenshots/tree.png) |

2026-10-30 验收：Pixel 7 / Android 15 模拟器启动成功；`flutter analyze` 无问题；
`flutter test` 5 项全部通过；debug APK 已构建并安装运行。

## 当前进度

| 模块 | 目录 | 状态 |
| --- | --- | --- |
| Flutter iOS / Android | `apps/mobile` | ✅ Android 原型可运行，iOS 工程已生成（需 macOS 构建） |
| React Web | `apps/web` | 📁 占位，后续开发 |
| 鸿蒙端 | `apps/harmony` | 📁 占位，需单独验证 Flutter/ArkUI 路线 |
| 微信小程序 | `apps/mini-program` | 📁 占位，后续独立实现并复用 API |
| Go 服务端 | `server` | 📁 占位，暂不开发 |
| API 契约 | `packages/api-contracts` | 📁 占位 |

已实现的首期移动端页面：

- **首页**：水墨家族头图、家族概览、六个快捷入口、最新动态。
- **族谱树**：可缩放 / 拖动的五代世系、世代筛选、人物选中态、底部人物摘要。
- **人物档案**：生平、亲属关系、资料版本提示。
- **成员查询**：姓名 / 籍贯 / 职业搜索、按世代筛选。
- **我的申请**、**资料申请**：完整展示「先申请、后审核」的交互边界（暂不写入）。
- **消息**、**我的**、**家族相册**、**家族故事**：可交互的原型页面。
- 底部导航：首页、族谱树、添加、消息、我的。

登录、真实数据读写、审核、上传和账号权限**尚未接入**，这些能力必须由服务端统一校验。
界面上带「原型 / 演示」提示的入口，不会假装已经完成持久化。

## 快速启动（Windows + Android 模拟器）

本机已安装并验证：

- Flutter `3.35.5` / Dart `3.9.2`
- Android SDK Platform 35 / 36、Build Tools 35.0.0、Platform Tools、Emulator
- NDK `27.0.12077973`、CMake `3.22.1`（首次 Gradle 构建时自动安装）
- AVD：`family_pixel`（Pixel 7 / Android 15 / x86_64）
- JDK：`C:\Program Files\Java\jdk-22`
- Gradle `8.12`，wrapper 使用华为云镜像（GitHub Releases 在本机不可达）

首次运行或模拟器没有启动时：

```powershell
# 1. 启动模拟器（AVD 已迁移到 D 盘，避免占满 C 盘）
$env:ANDROID_AVD_HOME = "D:\AppData\Local\Android\avd"
& "$env:ANDROID_HOME\emulator\emulator.exe" -avd family_pixel -gpu host

# 2. 确认设备在线
& "$env:ANDROID_HOME\platform-tools\adb.exe" devices

# 3. 运行 Flutter（建议使用 JDK 22；GitHub 不可达时加 --no-version-check）
$env:JAVA_HOME = "C:\Program Files\Java\jdk-22"
$env:GRADLE_USER_HOME = "D:\AppData\Local\Gradle"
# 清华镜像未收录本版本 Flutter Engine AAR，使用 Flutter 中国镜像
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
cd apps\mobile
flutter --no-version-check run -d emulator-5554
```

也可以直接执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\run-android.ps1
```

构建安装包：

```powershell
cd apps\mobile
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
flutter --no-version-check build apk --debug
# 产物：build\app\outputs\flutter-apk\app-debug.apk
# 安装：adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

### Flutter 检查

```powershell
cd apps\mobile
dart format --output=none --set-exit-if-changed lib test
flutter --no-version-check analyze
flutter --no-version-check test
```

> 说明一：新版 Android 命令行工具提示 `--licenses` 已不再需要，Flutter Doctor
> 可能仍显示 “Android license status unknown”。本项目所需 SDK 组件均已安装，
> 实际构建不受影响；不依赖 `flutter doctor --android-licenses`。
>
> 说明二：Flutter SDK 仍使用清华镜像，但该镜像目前没有本版本的 Engine AAR。
> `android/build.gradle.kts` 已为 `io.flutter` 增加 Flutter 中国镜像和官方仓库回退，
> 脚本也会把 `FLUTTER_STORAGE_BASE_URL` 指向 `https://storage.flutter-io.cn`。
> Gradle 发行包则通过 `gradle-wrapper.properties` 中的华为云镜像获取。

## iOS 云端打包（无签名）

仓库已包含 [.github/workflows/ios-unsigned.yml](.github/workflows/ios-unsigned.yml)：

- 在 GitHub Actions 的 `macos-15` Runner 上使用 Flutter 3.35.5 编译 iOS
- 不执行 Apple 签名，产出：
  - `Runner-unsigned.ipa`
  - `Runner-unsigned.app.zip`
  - `SHA256SUMS.txt`
- 推送到 `master` 且改动 `apps/mobile/**` 时自动触发，也可在 Actions 页面手动运行
- **无签名 IPA 不能安装到普通 iPhone，也不能上传 TestFlight**；它只用于验证 iOS 编译链路和提前产出待签名包

## 目录结构

```text
family-genealogy/
├── apps/
│   ├── mobile/                 # Flutter（iOS + Android）
│   │   ├── lib/                # 页面、主题、模型、演示数据
│   │   ├── android/            # Android 工程
│   │   ├── ios/                # iOS 工程
│   │   ├── assets/             # 水墨背景、字体、应用图标
│   │   └── test/               # Widget 冒烟测试
│   ├── web/                    # React 成员端 + 后台，预留
│   ├── harmony/                # 鸿蒙技术验证，预留
│   └── mini-program/           # 微信小程序，预留
├── server/                     # Go REST API，当前不实现
├── packages/
│   └── api-contracts/          # OpenAPI / 错误码，预留
├── data/                       # 本地 JSON 与媒体数据的未来位置
├── deploy/                     # Nginx / Docker Compose，预留
├── docs/
│   ├── reference/              # 规划报告与 UI 参考图
│   ├── screenshots/            # Android 模拟器运行截图
│   └── development.md          # 技术决策与后续路线
├── scripts/
│   └── run-android.ps1
└── README.md
```

## 设计原则

1. 账户（User）与人物（Person）分离，不以姓名作为唯一标识。
2. 普通成员不直接覆盖正式档案；修改先生成申请，审核通过后才写入。
3. 权限、数据校验、审计必须由服务端执行，客户端按钮隐藏不等于权限控制。
4. 示例数据只存于 `lib/data/demo_data.dart`，不冒充真实后端数据。
5. 族谱树优先纵向世系，移动端重点优化缩放、拖动与人物摘要。

## 下一步

1. 在 Android 真机 / 模拟器上继续打磨首页与族谱树交互。
2. 冻结 Person / Relationship / EditRequest 数据结构，输出 OpenAPI 草案。
3. 实现 Go API + JSON Repository（含原子写、备份、审计），再接 Flutter。
4. 复用同一套 API 开发 React 成员端与独立后台管理端。
5. 单独评估鸿蒙与小程序，不阻塞首期交付。

详细说明见 [docs/development.md](docs/development.md)。
