# 开发说明与阶段路线

## 1. 为什么先做 Flutter

规划报告建议以「数据模型 → Go API → React → Flutter」推进，这是降低返工风险的稳妥顺序。
当前在你明确要求下，先完成 **Flutter 端可运行原型**，用于尽早确认视觉方向和族谱树交互，
同时把界面里的能力边界标清楚：

- 原型阶段只消费 `lib/data/demo_data.dart` 的静态演示数据。
- 任何「申请」「新增」「上传」入口都不写正式数据，并明确提示服务端未接入。
- 页面结构、实体 ID 与字段命名按未来 API 契约保留，后续替换数据源即可。

原型完成后，应先冻结数据模型与服务端接口，再继续扩展页面，避免把演示逻辑固化到 UI。

## 2. 多端目录约定

| 端 | 目录 | 技术路线 | 当前动作 |
| --- | --- | --- | --- |
| 移动端 | `apps/mobile` | Flutter 3.35 / Dart 3.9 | 开发中 |
| Web 成员端 + 后台 | `apps/web` | React + TypeScript + Vite | 待建 |
| 鸿蒙 | `apps/harmony` | 单独技术验证，可采用 Flutter 社区方案或 ArkUI | 待评估 |
| 微信小程序 | `apps/mini-program` | 独立前端，复用 HTTP API | 待建 |
| 服务端 | `server` | Go + REST + JSON Repository | 待建 |

鸿蒙不能因为「Flutter 能编译」就判定完成，需要逐项验证插件、文件系统、图片选择和发布链路。
小程序同样需要独立评估登录、域名白名单与文件上传限制。

## 3. Flutter 工程结构

```text
apps/mobile/lib/
├── main.dart                    # 系统栏、方向、入口
├── app.dart                     # MaterialApp、主题、中文本地化
├── core/
│   ├── theme/                   # 颜色与字体主题
│   └── widgets/                 # 卡片、状态标签、头像、页头
├── data/demo_data.dart          # 静态演示数据（未来 Repository 替换点）
├── models/                      # FamilyMember / EditRequest / Message
└── features/
    ├── shell/                   # 底部导航与「添加」动作面板
    ├── home/
    ├── tree/
    ├── person/
    ├── search/
    ├── requests/
    ├── messages/
    ├── profile/
    ├── gallery/
    └── stories/
```

约束：

1. 页面不直接拼装 API 地址；未来统一使用 `ApiClient` + Repository。
2. 用户与人物分离。演示中的「张三」对应 `person_zhang_san`，但还没有真实 User 记录。
3. 所有写操作在服务端重新做身份、家支范围和版本校验，客户端不做可信权限判断。
4. 生成的背景与人物插画由 `apps/mobile/tool/generate_assets.py` 产生，无第三方图片版权风险。

## 4. 当前已覆盖的交互

- 首页快捷入口跳转、待审核资料入口、家支概览底部面板。
- 族谱树：双指缩放、拖动、缩放按钮、世代聚焦、节点选中、人物档案跳转。
- 成员查询：搜索、按世代筛选、空状态、人物详情。
- 人物关系：演示数据提供配偶、父母、子女关系，族谱树与人物档案保持一致。
- 我的申请：状态筛选、申请详情、审核意见、演示提交。
- 消息：已读状态、全部已读、消息详情。
- 相册与故事：浏览型交互与内容页。
- 底部添加：新增人物 / 关系 / 上传均明确提示「待服务端接入」，资料申请可进入表单。

## 5. 下一阶段建议

### 5.1 先冻结数据契约

建议优先确认：

- `Person`：`id`、`familyId`、`branchId`、姓名 / 别名、性别、生卒日期、籍贯、居住地、
  职业、生平、头像、照片、`status`、`version`、时间戳。
- `Relationship`：方向约定（父母 / 子女 / 配偶），禁止重复保存反向关系。
- `User`：`personId`、`username`、`passwordHash`、`role`、`status`。
- `EditRequest`：`baseVersion`、字段白名单、`pending/approved/rejected/cancelled` 状态机。
- 日期必须允许「年-only / 生辰不详 / 旧历」，不要强转成不准确的公历。

### 5.2 服务端最小闭环

1. Go API 框架与统一错误码。
2. Repository 接口 + JSON 实现（互斥写、临时文件、原子替换、备份）。
3. 普通成员登录、本人资料申请、族长审核。
4. 审计日志与照片上传白名单。
5. Flutter 用 Repository 替换 `DemoData`，保留空状态、加载与错误状态。

### 5.3 移动端下一步

- 把族谱树布局改为由 Relationship 图计算（当前节点位置是固定演示坐标）。
- 抽象 `FamilyRepository` 并实现本地假数据 / HTTP 双实现。
- 为族谱树、审核流程补 Widget / Golden 测试。
- 真机测试中文字体、状态栏安全区、低端机缩放性能与图片内存。
- 为 iOS 在 macOS 上补签名、真机与发布流程验证。

## 6. 本机环境与构建记录

| 项目 | 位置 / 版本 |
| --- | --- |
| Flutter | `D:\install\flutter` · 3.35.5 / Dart 3.9.2 |
| Android SDK | `D:\AppData\Local\Android\Sdk` · Platform 35 / 36 |
| Build Tools | 35.0.0 |
| NDK / CMake | 27.0.12077973 / 3.22.1（构建时补装） |
| Emulator | `D:\AppData\Local\Android\Sdk\emulator` · 37.2.12 |
| AVD | `family_pixel` · Pixel 7 / Android 15 (API 35) / x86_64 |
| AVD 数据目录 | `D:\AppData\Local\Android\avd` |
| JDK | `C:\Program Files\Java\jdk-22`（Flutter 已设为 jdk-dir） |
| Gradle | 8.12（wrapper 华为云镜像） |
| Gradle 缓存 | `D:\AppData\Local\Gradle` |
| Flutter Engine AAR | Flutter 中国镜像 / 官方仓库回退 |
| Git 远端 | Gitee `origin` + GitHub `github` |
| GitHub 仓库 | `43374166/family-genealogy`（Public） |
| iOS CI | `.github/workflows/ios-unsigned.yml`，macOS 15 无签名构建 |

2026-10-30 完成的真实构建验证：

1. `flutter build apk --debug` 成功，产物
   `apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`。
2. APK 安装到 `emulator-5554` 并以 `cn.familytree.family_tree/.MainActivity` 启动。
3. 首页、族谱树、人物档案、成员查询、申请、消息、我的、相册、故事、添加面板
   均在模拟器实际打开并截图。
4. `flutter analyze` 无问题；`flutter test` 5 项通过。
5. GitHub Actions 首次 macOS 无签名 iOS 构建成功：run
   [40920458742](https://github.com/43374166/family-genealogy/actions/runs/40920458742)，
   Artifact `family-tree-ios-unsigned-1` 约 31 MB，包含未签名 IPA、Runner.app.zip
   与 SHA256 校验和。

网络注意事项：

- 本机无法访问 GitHub，Flutter 版本检查会等待约 20 秒，命令统一加
  `--no-version-check`。
- 清华 Flutter 镜像缺少本版本 Engine AAR（404）；项目在 Gradle 中增加了
  `https://storage.flutter-io.cn/download.flutter.io` 与官方仓库回退。
- Gradle 官方 `services.gradle.org` 会重定向到 GitHub Releases，wrapper 改用
  华为云镜像下载同一官方 Gradle 8.12 发行包。
- 新版 `sdkmanager` 已把 `--licenses` 标记为无需执行；Flutter Doctor 的
  license unknown 提示不影响已安装 SDK 组件的构建。

## 7. 安全边界

- 当前没有账号系统，也没有真实成员隐私数据。
- 演示图片为程序生成插画，不含真实家族照片。
- 后续接入服务端前，不要把 `data/` 下的正式 JSON 或媒体文件提交到 Git。
- 环境变量、签名文件与服务器密钥统一放入 `.env` / 本地密钥库，并保持被忽略状态。
