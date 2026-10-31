# apps/mobile · Flutter（iOS / Android）

「家族族谱」多家族 Flutter 移动端。登录、首页、动态族谱树、人物详情和成员搜索
已经接 MySQL + Go 的真实 API；其他页面仍使用演示数据。APP 品牌不绑定任何姓氏，
当前家庭由登录账户决定。

## 运行

```powershell
$env:JAVA_HOME = "C:\Program Files\Java\jdk-22"
$env:GRADLE_USER_HOME = "D:\AppData\Local\Gradle"
$env:FLUTTER_STORAGE_BASE_URL = "https://storage.flutter-io.cn"
flutter --no-version-check pub get
flutter --no-version-check run -d emulator-5554
```

> 清华 Flutter 镜像缺少本版本的 Engine AAR。Gradle 已配置 Flutter 中国镜像
> 和官方仓库回退；这里的 `FLUTTER_STORAGE_BASE_URL` 用于 Flutter 侧下载。

或在仓库根目录执行 `scripts/run-android.ps1`。

## 检查

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter --no-version-check analyze
flutter --no-version-check test
```

## 连接本地 API

默认 API 地址为当前开发机 `http://192.168.1.201:8080`，登录页可直接修改服务器地址。
Android 模拟器构建时建议覆盖为宿主机地址：

```powershell
flutter --no-version-check build apk --debug `
  --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

iOS 真机必须与电脑在同一局域网，并允许“本地网络”权限。当前为开发阶段，iOS
`Info.plist` 和 Android Manifest 都临时允许明文 HTTP；生产环境必须改 HTTPS 并移除。

演示账号：`linglei / Demo#2026`。会话令牌只保存在内存中，杀掉 App 后需要重新登录。

## 数据与后端

- `lib/services/api_client.dart`：登录、族谱树、人物详情、成员搜索、资料申请和审核 API。
- `lib/services/app_session.dart`：当前账户、家庭、族谱树和登录状态。
- `lib/features/tree/tree_layout.dart`：按 API 关系和世代计算的动态族谱布局。
- `lib/data/demo_data.dart`：尚未接 API 的页面仍从这里读取演示数据。

资料申请支持修改籍贯、现居地、职业、教育和生平；审核通过后由服务端事务写入并记审计。
底部“添加”可新增人物、添加父母/配偶关系；owner/admin 直接写入，普通成员提交
写入申请并由族长审核。登录页支持邀请码注册；成员可在“我的”申请绑定族谱人物，
族长在“绑定审核”通过后建立账号与人物关联。手机号字段已预留，短信一键登录未接。族长可生成“分支管理员”邀请码并指定
管辖家支；分支管理员只能审核和写入本支及下级支。族长可在“分支管理员”页直接
任命已有成员或撤销权限。邀请码可展示二维码，扫码得到邀请码后注册。
注册页邀请码可选：不填会创建一个个人家族并成为族长，填了则加入对方家族。账号可拥有
多个家族，在“我的—我的家族”切换、创建新家族，或用邀请码/App 内扫码加入别人的家族。
族长还可生成旁支数据导入码（二维码），目标家族族长预览后选择分支、世代和挂靠父辈导入。
首页“家族相册”可上传/浏览照片，支持关联人物、说明和拍摄时间；人物详情页展示其照片。照片存私有 OBS，通过登录鉴权读取。
族谱树第一次进入会默认聚焦到本人节点；顶部“自己”按钮可重新定位，切家族后也会聚焦新家族的本人。我的页头像可上传，人物头像同步到族谱树；“我的二维码”展示真实家族邀请码。
提供用户协议、隐私政策、修改密码、族长转让、家族数据 JSON 导出、家族归档注销和账号注销；注册/继续使用前需同意协议。忘记密码可用一次性找回码重置，登录连续失败会临时锁定。\n\n“我的”页只保留真实入口和统计（成员、家支、本人世代、加入时间）；“我的—设置”提供账号信息、字体大小、清除缓存、隐私说明、家族管理、版本与退出登录。
首页成员数、家支数、本人世代、家支概览和最新动态均来自当前家族真实数据。
家族故事支持真实列表、详情、新建、编辑和删除；消息页显示站内通知、未读红点和资料/绑定申请入口，通知每 45 秒自动刷新。登录页支持手机号验证码登录；登录后
可在“我的—手机号”绑定手机号。登录令牌存入系统安全存储，重启 App 自动恢复会话，
退出登录后清除。
owner/admin 可在人物详情直接编辑资料，并在亲属关系中删除错误关系；普通成员从同一
编辑页提交完整资料修改申请，由族长或管理员审核后事务应用。普通成员点击亲属关系
删除按钮会提交关系纠错申请，审核通过后删除关系。

## 设计资产

- `assets/images/hero_ink.jpg`：首页水墨头图
- `assets/images/tree_paper.jpg`：族谱树纸纹背景
- `assets/fonts/NotoSerifSC-SemiBold.ttf`：标题宋体（OFL 1.1）
- 人物肖像是 Flutter `CustomPainter` 绘制的插画，不依赖外部照片
- 重新生成背景与应用图标：

```powershell
python tool/generate_assets.py
```

生成脚本依赖 Pillow，建议在仓库根目录使用项目约定的 Python 环境执行。

## 已实现页面

首页、族谱树、人物档案、成员查询、我的申请、资料申请、消息、我的、
家族相册、家族故事；底部导航内的「添加」会打开动作面板。

族谱树由 `tree_layout.dart` 按 API 的父母子女、配偶和世代关系实时计算坐标；
新增家庭或成员时无需再修改固定坐标。

- Android 应用名：`家族族谱`
- iOS 应用名：`FamilyTree`（Apple 签名对应用名有 ASCII 限制）
- 家庭标题：来自登录账户的家庭资料，当前为「凌氏家族」，产品品牌不绑定姓氏

关系数据（配偶 / 父母 / 子女）已在 `DemoData` 中显式维护，不应从姓名推断。

## iOS 无签名打包

`.github/workflows/ios-unsigned.yml` 会在 GitHub 的 macOS Runner 上执行：

```bash
flutter build ios --release --no-codesign
```

然后把 `Runner.app` 打包为 `Runner-unsigned.ipa` 和 `.app.zip`，作为 Actions
Artifact 保存。该包没有签名，不能直接安装到正常 iPhone，也不能上传 TestFlight；
签名材料准备好之后，再增加证书、Provisioning Profile 和导出步骤即可。

## 已验证

- Pixel 7 / Android 15 模拟器安装运行成功。
- `flutter analyze` 无问题。
- `flutter test` 5 项通过（Widget 冒烟 + 演示关系一致性）。
- Debug APK：`build/app/outputs/flutter-apk/app-debug.apk`。
