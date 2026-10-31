# 开发说明与阶段路线

## 1. 为什么先做 Flutter

规划报告建议以「数据模型 → Go API → React → Flutter」推进，这是降低返工风险的稳妥顺序。
当前在你明确要求下，先完成 **Flutter 端可运行原型**，用于尽早确认视觉方向和族谱树交互，
同时把界面里的能力边界标清楚：

- 原型阶段只消费 `lib/data/demo_data.dart` 的静态演示数据。
- 任何「申请」「新增」「上传」入口都不写正式数据，并明确提示服务端未接入。
- 页面结构、实体 ID 与字段命名按未来 API 契约保留，后续替换数据源即可。

数据模型与 OpenAPI 契约已冻结为 v1；运行库确定为 MySQL 8.4，PostgreSQL 17 DDL 仅作为
设计参考保留。下一步按契约实现认证与只读 API，再扩展页面，避免把演示逻辑固化到 UI。

## 2. 多端目录约定

| 端 | 目录 | 技术路线 | 当前动作 |
| --- | --- | --- | --- |
| 移动端 | `apps/mobile` | Flutter 3.35 / Dart 3.9 | 开发中 |
| Web 成员端 + 后台 | `apps/web` | React + TypeScript + Vite | 待建 |
| 鸿蒙 | `apps/harmony` | 单独技术验证，可采用 Flutter 社区方案或 ArkUI | 待评估 |
| 微信小程序 | `apps/mini-program` | 独立前端，复用 HTTP API | 待建 |
| 服务端 | `server` | Go 1.25 + MySQL 8.4（PG 17 设计参考） | 基础层已建，业务 API 待开发 |

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
2. 用户与人物分离。当前 owner 账号 `linglei` 已绑定人物「凌磊」；后续成员通过
   绑定申请建立 User 与 Person 的关联。
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

1. MySQL 8.4 schema + 迁移 + Go API 骨架（已完成）。
2. 登录/会话、家庭成员与家支的只读 API（已完成）。
3. 族谱树和人物详情 API（已完成）；Flutter 登录、首页、动态族谱树、人物详情和
   成员搜索已接 API。
4. 资料申请、审核事务、审计（update_person 与新增人物/关系闭环）；owner/admin
   直接写入，普通成员提交写入申请；邀请码注册、人物绑定和分支管理员邀请/范围审核
   已实现，邀请码二维码和手机号验证码登录/绑定已接入（华为云 MSGSMS，需配置密钥），
   登录会话持久化、每日备份/恢复、人物编辑、关系删除、成员完整资料申请和关系纠错
   申请已接入；多家族账号、无邀请码注册、创建/切换家族、邀请码/扫码加入家族、旁支
   数据导入码/预览/分支世代映射已接入；照片存私有 OBS `fishdream-family`，
   相册上传/浏览/删除、人物关联/说明/拍摄时间已接入；族谱树“自己”定位、设置页
   （账号/字体/缓存/隐私/退出）已接入；首页统计和动态来自真实族谱/审计数据；
   家族故事 CRUD、站内通知中心、人物头像（私有 OBS）和我的邀请二维码已接入；
   族谱树首次进入默认聚焦本人，切换家族后聚焦新家族的本人；用户协议/隐私政策、
   找回码重置密码、登录连续失败锁定（5 次/15 分钟）、修改密码和账号注销已接入；
   族长可在设置中把族长转让给其他成员；族长可导出完整 JSON 数据，或在仅剩自己时
   注销并归档家族（保留族谱、照片、故事和审计）。
5. 其余 Flutter 页面替换 `DemoData`，补齐空状态、加载与错误状态。

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
