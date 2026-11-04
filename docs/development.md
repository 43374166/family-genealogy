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
| Web 成员端 + 后台 | `apps/web` | React 18 + TypeScript + Vite 7 + Semi + Redux | ✅ 成员端已完成，独立后台待拆 |
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
   注销并归档家族（保留族谱、照片、故事和审计）。生日/祭日支持公历、农历（含闰月）
   选择，首页按未来 60 天展示生日与祭日提醒，同时显示农历和阳历日期。族长可按
   世代配置字辈，人物选择字辈时自动匹配世代，族谱树显示“第几世（字辈）”。
   2026-11-02 新增：头像上传前在 App 内裁切，族长/管理员可为任意成员设置头像；
   相册支持一次多选上传、照片关联多位人物并按多人物筛选；故事支持最多 9 张压缩
   配图；生日按农历年份自动换算生肖；加入新家族时自动归档空的原家族，有数据时
   生成家族合并申请，目标家族族长可选择人物/故事/照片并指定家支、起始世代和
   挂靠父辈；服务端 Problem 详情与标题统一为中文；客户端默认连接线上
   `https://family.fishdream.xyz:10443`，iOS 打包同样使用线上地址。
   2026-11-02 体验更新：首页支持下拉刷新，生日/祭日卡片与上下卡片同宽；全局
   圆角收紧；设置新增“亮色 / 暗色 / 跟随系统”主题，暗色模式保留照片、头像、
   二维码和裁剪编辑器的原始颜色；人物详情“照片”只显示仅关联本人的个人照片。
   同日修复：族长/管理员在“编辑人物”里修改父亲或母亲后，关系没有写入服务端；
   族谱树去掉配偶桥接线，父母到子女的连线统一从各自卡片中心引出。
   非本姓（母亲方）成员在新增或编辑时，父母选择改为“配偶（男方）”选择，配偶列表
   只显示男性，并在选中配偶后自动同步世代与家支，保证配偶关系能写入。
   2026-11-02 删除与多配偶：人物档案新增删除入口（服务端软删除，结束亲属关系、
   解除账号绑定与照片人物标记，保留审计）；族谱树把丈夫的多位配偶排在他的旁边，
   每对夫妻的子女共用一条横向连接线，父亲和母亲都从各自卡片正中心向下接入这条横线，
   再由横线分别落到每个子女；不同配偶的横线使用独立锚点和错开的层级，避免线条重合。
   同日新增 `apps/harmony` 原生鸿蒙端（ArkTS/ArkUI）：登录、首页、族谱树、成员查询、
   人物档案、新增人物、删除人物接入同一套线上 API；随后补充家族相册（筛选/上传/查看/
   删除）与头像中心方形裁剪，照片和头像均通过带鉴权的图片接口加载。
   线上域名目前只有 IPv6 记录；Nginx 在 10080 端口新增仅内网可访问的
   `/family-api/` HTTP 入口，鸿蒙登录遇到解析失败时会自动回退到该局域网地址。
   鸿蒙端随后补齐家族故事：列表、详情、新建（标题/正文/关联人物/最多 9 张配图）、
   作者或族长删除；故事编辑和图片全屏查看仍待后续。
   鸿蒙端继续补齐消息中心（通知、未读数、单条/全部已读）和资料/绑定审核
   （待审列表、通过、拒绝及审核意见）；逐字段差异和消息跳转仍待后续。
   鸿蒙端家族合并已接入申请列表、详情和族长审核，可选择人物/故事/照片、
   目标家支、起始世代和挂靠父辈；合并申请仍由服务端在成员加入新家族时自动创建。
   鸿蒙端随后接入数据导入导出：族长可将完整家族 JSON 保存到系统文件位置，
   可生成旁支一次性导入码，也可输入导入码预览后选择家支、世代和父辈导入。
   鸿蒙端开始做视觉对齐：统一 Flutter 的 `#F4F7F8` 纸色、墨色/主色、卡片阴影和圆角，
   首页改为水墨背景 + 家族印章 + 三格统计 + 六个快捷入口，底栏改为五项并加悬浮新增按钮，
   消息独立成底栏页；人物档案改为渐变人物卡 + 头像 + 徽章 + 三格信息 + 照片横排，
   族谱树改用衬线标题和圆形操作按钮；后续继续对齐相册、故事、审核和合并页面。
   鸿蒙族谱树进一步按 Flutter 重做：宽卡 150×82、紧凑卡 96×128（按世代密度切换），
   纸张纹理背景、世代筛选、双指缩放/单指拖动、缩放按钮、选中人物底部摘要；
   布局改为按子树宽度居中，不再等距平铺。
   鸿蒙端开始补账号与家庭：切换家族、邀请码加入、创建家族、邀请码列表/新建/复制、
   家族账号列表、修改密码和注销账号；下一步补注册/找回密码/手机验证码、
   家族资料与家支管理。
   鸿蒙端账号与家庭已补齐注册、手机验证码登录、找回密码、绑定手机、一次性找回码、
   族长转让和归档家族；家族资料/家支/角色接口服务端尚未提供，暂时保留为后续项。
   鸿蒙端人物关系已接入编辑资料、添加父母/配偶/子女、删除关系（普通成员会提交纠错申请）
   和绑定人物申请；资料修改申请、生肖和高级搜索仍待补。
   鸿蒙相册支持多人关联、照片说明/拍摄日期编辑；故事支持编辑已有故事和图片全屏查看。
   上传前压缩仍待补。
   鸿蒙审核与消息已补齐普通成员资料修改申请、我的申请、逐字段修改详情，
   通知可跳转人物、故事、相册和审核中心；剩余推送与深色主题。
   鸿蒙相册上传前压缩到最长边 1600/JPEG 78；人物档案补生肖标签，成员搜索支持籍贯、现居、职业、教育。
   服务端新增 `PATCH /api/v1/family` 家族资料更新（名称/姓氏/家训/地区/简介），
   鸿蒙“账号与家庭”页可直接编辑；家支和成员角色接口仍待补。
   服务端继续新增 `POST/PATCH /api/v1/branches`（家支新增、改名/排序）和
   `PATCH /api/v1/accounts/{userID}`（族长设置管理员/成员）；鸿蒙家庭页已接入，
   家支删除仍待后续。
   服务端补 `DELETE /api/v1/branches/{id}`（仅无人物使用时允许），鸿蒙家庭页支持家支删除；
   导入码增加二维码展示。
   鸿蒙端邀请码也支持二维码展示，消息未读数每 60 秒轮询一次，作为无系统推送时的兜底。首页下拉刷新后会主动清除遗留的 overscroll/惯性偏移并回到顶部，
   修复刷新后页面自动向下滑动的问题。
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

- 账号、会话、角色与家族数据都由 Go 服务端校验；Web 端不把隐藏按钮当作权限控制。
- 本地演示数据与演示图片只用于联调；真实照片存放在私有 OBS，不能提交到 Git。
- `data/` 下的正式 JSON 与媒体文件不得提交；环境变量、签名文件与服务器密钥统一放入
  `.env` / 本地密钥库，并保持被忽略状态。
- 浏览器端令牌存放在 `localStorage`，只在同源 HTTPS 环境部署；公共设备应及时退出。
  服务端只保存令牌哈希。

## 8. Web 成员端实现（2026-11-03）

`apps/web` 已从占位目录升级为可运行成员端，复用 Go API，不复制业务后端。

### 8.1 技术决策

- **React 18 + Vite 7 + TypeScript**：与仓库现有 Web 规划一致；React 18 是 Semi
  2.104 兼容性最稳的版本。
- **react-router-dom 7**：`RequireAuth`、`GuestOnly`、`RequireReviewer` 三个路由守卫，
  登录后回到来源路径；普通成员访问 `/family` 会重定向。
- **Redux Toolkit**：`authSlice` 管理 token/me/家族身份，`notificationSlice` 管理未读与
  消息状态，`uiSlice` 管理主题、侧栏和移动抽屉；页面数据读取由 `useAsync` 统一处理
  取消、竞态和刷新。
- **Semi Design**：使用 Semi 的 Button / Input / Select / SideSheet / Modal / Tabs /
  Toast / Dropdown / Avatar / Badge / Skeleton 等基础组件，再通过 CSS 变量统一纸本
  墨色、圆角、阴影和暗色主题。`SafeSelect` 把 Semi Select 的复杂泛型收窄，规避 TS 5.8
  下动态 optionList 的类型实例化过深问题。
- **扁平的 axios 请求层**：参考 md2card 的 `createFlatRequest` 思路，
  `flatRequest<T>` 返回 `{ data, error, status }`，页面使用 `request<T>` 抛出统一
  `ApiError`；错误按 RFC 9457 的 `detail → title → HTTP 状态` 提取。401 只触发一次
  `auth:expired` 事件，由根组件清 token 并交给路由守卫跳转。
- **鉴权图片**：相册内容与头像接口都要求 `Authorization`，因此不能用裸 `<img src>`。
  `useAuthedImage` 先拉 Blob，再以 object URL 渲染，并按 token + path 缓存。
- **族谱树**：按 Flutter 端森林布局重写。家庭单元（夫妻/多配偶/单人）组成森林；
  每个子单元只挂一个布局父单元，递归计算子树宽度，父单元居中在所有子女子树之上，
  兄弟子树独立展开并保留固定间距，不再把每代卡片强制挤成一条线。React Flow 负责
  视口、缩放、拖拽、定位和自定义节点。夫妻并排渲染，但父代到子代按「父亲、母亲」
  分别绘制两条线，二婚/一夫多妻时每个孩子从自己的父母卡片出发，不再从家庭单元中心
  合并。布局是纯函数并有 9 项 Vitest 单测。树页占满顶栏以下视口，页面不纵向滚动；
  滚轮缩放、拖拽平移；首次和点击人物时按人物卡中心聚焦。同层优先按子代数量降序，
  再按排行/出生年排序，主支优先显示在左边。人物卡改为头像在上的窄竖版布局，固定
  120×148，保证同一世代顶边和高度一致；保留双历/生肖/世代信息。
- **全屏与印刷导出**：族谱页支持 Fullscreen API 全屏/退出；`TreeExportView` 在屏幕外按
  1:1 布局重绘完整森林（不依赖当前视口），再用 `html-to-image` 以 5x pixelRatio 输出
  无损 PNG；PDF 用同一张 5x PNG 嵌入 A3。26 人实测 PNG 11650×4790（23.9 MB），
  卡片约 600×740 像素，可放大阅读；离屏导出同时等待头像图片加载。
- **谱书工作区**：`/books` 使用本地项目模型（按家族存 `localStorage`），四步流程
  封面选择 → 版式设计 → 编辑内容 → 制作成谱书；`formBookPages` 按世代自动分章，
  每页最多 4 人，生成封面/扉页/序/章节/人物/谱成页；预览支持 3D 翻页与筒子页折痕。
  导出当前跨页 PNG、全本逐页 PNG（ZIP）和全本 A4 PDF，均以 5x 截图生成。
- **双历与生肖**：`lunar-typescript` 将人物生卒日期在公历/农历间互转，节点卡、侧卡和
  人物档案同时展示两套日期、干支年（如甲午年）和生肖；闰月与不完整日期都有降级显示。
- **人物头像**：Web 编辑抽屉支持 JPEG/PNG/WebP（≤5 MB）选择、预览、保存时上传与移除；
  复用服务端私有 OBS 头像接口，图片路径附带人物 version 以刷新鉴权图片缓存。
- **响应式**：桌面使用固定侧栏 + 顶栏；移动端使用抽屉导航 + 底部五项导航，族谱树
  默认聚焦中段家庭单元而不是把整棵树缩成缩略图。

### 8.2 已实现页面

登录（账号密码 / 扫码）、注册、家族首页、族谱树、成员查询、人物档案、个人影像、
家族相册、家族故事列表与阅读页、消息中心、审核中心/我的申请、我的、家族管理
（资料/家支/账号/邀请码/字辈）。

### 8.3 验收

2026-11-04 在 Windows + Chromium 下完成：

- `pnpm typecheck`、`pnpm lint` 通过；
- `pnpm test` 17 项测试通过（9 项布局/多婚姻连线/子代排序/人物居中 + 5 项双历/生肖转换 + 3 项谱书分页）；
- `pnpm build` 通过（Semi / React Flow 分包）；
- 真实 API 登录、扫码登录全流程、族谱树点击/定位、人物档案、故事新建与详情、
  资料审核通过、暗色主题、普通成员权限、移动端抽屉与族谱树聚焦走查；
- 截图见 `docs/screenshots/web/`。

### 8.4 已知边界

- 相册/头像上传需要服务端配置私有 OBS；Web 的上传、成员关联、灯箱和错误分支已实现，
  本地无 OBS 时只能展示空相册。
- 谱书工作区当前按浏览器本地存储，尚未接入服务端多人协作/跨设备同步；导出是 5x 光栅
  PNG/PDF，而不是可编辑的矢量印刷源文件。
- 独立 `/admin` 后台尚未拆分；`/family` 覆盖族长/管理员日常维护。
- 短信验证码、导出、绑定申请审核、家族合并审核仍以 Flutter / HarmonyOS 为主；
  Web 已支持扫码登录，消息中的合并通知目前落到「我的」。
- OpenAPI 仍需同步服务端后来新增的接口；Web 类型以 Go handler 实际输出为准。

## 9. 云端数据同步与扫码登录（2026-11-04）

### 9.1 数据库同步

- 云端 `family.fishdream.xyz:10443` 的 MySQL 通过既有 `familytree-backup` 逻辑生成
  一致性备份，再经 `scripts/pull-familytree-backup.ps1` 拉回 `backups/`；
- 导入前先用 `mysqldump --single-transaction --no-tablespaces` 备份本地库；
- 导入时移除 dump 中 root `DEFINER`，避免本地应用账号无法创建触发器；
- 校验结果：云端 / 本地均为 2 用户、26 人物、1 故事、2 照片、迁移版本 22。
- 客户端 API 统一指向云端实际监听端口 **10443**；用户提供的 10433 当前未监听，不做
  假设。

### 9.2 扫码登录协议

- 迁移 `00022_qr_login_sessions.sql` 新增 `auth_qr_sessions`，保存 secret 哈希、状态、
  请求 IP/城市/地区/设备、二维码所有者与确认家族；状态机为
  `pending → scanned → confirmed → consumed`，另有 `expired` / `cancelled`。
- 公开接口：`POST /api/v1/auth/qr`、`GET /api/v1/auth/qr/{id}?secret=`、
  `POST /api/v1/auth/qr/{id}/cancel`；登录后接口：
  `POST /api/v1/auth/qr/{id}/scan`、`POST .../confirm`。
- 二维码内容为 `familytree://web-login?v=1&id=...&secret=...`；手机端只接受该 scheme。
- 轮询仅在 `confirmed` 后签发一次正常 Bearer 会话，随后置为 `consumed`，再次轮询
  返回 `QR_ALREADY_USED`；二维码 2 分钟过期。
- 服务端从 Nginx 的 `X-Real-IP` 取真实客户端 IP，并对 loopback/私网来源才信任代理头；
  归属地查询失败不阻塞登录。
- Web 登录页使用 `qrcode.react` 渲染，展示城市、IP、设备和倒计时；Flutter 只有一个
  右上角扫码入口，按 `familytree://web-login` 协议进入网页登录确认页，其他邀请码走
  加入家族页。

### 9.3 验收

- 本地 QR API：创建 → 登录账号 → scan → confirm → 浏览器轮询拿到会话 → `/me`
  成功；重放返回 409，错误 secret 返回 404，取消后状态为 `cancelled`；
- 云端 API 已部署 `/healthz` 正常，QR 创建返回真实 IPv6 与归属地「北京」；
- Web Chromium 扫码全流程通过，二维码页展示云端城市与设备；
- Flutter `analyze` 无问题，`test` 17 项通过（含 QR payload 解析）。
