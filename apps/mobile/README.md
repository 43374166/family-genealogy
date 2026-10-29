# apps/mobile · Flutter（iOS / Android）

张氏族谱的 Flutter 移动端原型。目前以 Android 为验证目标；iOS 工程已生成，
需在 macOS + Xcode 上完成签名和构建验证。

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

## 数据与后端

`lib/data/demo_data.dart` 是纯静态演示数据。当前没有网络层，也没有真实登录、
写入或文件上传；页面中相关入口会明确标注为原型能力。接入 Go API 后，应以
Repository 替换 `DemoData`，并补齐加载态、错误态、空状态与权限数据。

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

族谱树目前使用固定演示坐标；接入后端后，应根据 Relationship 图计算布局。
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
