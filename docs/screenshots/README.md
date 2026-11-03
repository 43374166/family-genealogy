# App 运行截图

## Flutter 移动端

以下截图均来自本机 **Pixel 7 / Android 15 (API 35) 模拟器**，Flutter 3.35.5，
`Impeller (OpenGLES)` 渲染，2026-10-30 运行。

| 页面 | 截图 |
| --- | --- |
| 首页 | [home.png](home.png) |
| 族谱树 | [tree.png](tree.png) |
| 人物档案 | [person.png](person.png) |
| 成员查询 | [search.png](search.png) |
| 我的申请 | [requests.png](requests.png) |
| 资料申请 | [profile-edit.png](profile-edit.png) |
| 消息 | [messages.png](messages.png) |
| 我的 | [profile.png](profile.png) |
| 家族相册 | [gallery.png](gallery.png) |
| 家族故事 | [stories.png](stories.png) |
| 添加动作面板 | [add-sheet.png](add-sheet.png) |

## 说明

- 全部页面使用本地演示数据，没有访问任何服务端。
- 人物头像为 Flutter `CustomPainter` 绘制的插画；头图与树纸背景由
  `apps/mobile/tool/generate_assets.py` 生成。
- 应用安装包路径：`apps/mobile/build/app/outputs/flutter-apk/app-debug.apk`。
- 截图中的「原型 / 待服务端接入」提示是刻意保留的能力边界，不代表功能已完成持久化。

## Web 成员端

Web 端截图独立放在 [web/README.md](web/README.md)，使用 React 18 + Vite 7 +
Semi Design，连接真实 Go API，分别提供桌面端与移动视口截图。其中扫码登录页连接云端
`https://family.fishdream.xyz:10443`，显示请求 IP 归属城市、设备、IP 和倒计时；
手机 App 确认后才签发会话。
