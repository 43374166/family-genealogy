# Web 成员端运行截图

以下截图来自本机 Chromium（真实 Go API + MySQL 数据），
React 18 + Vite 7 + Semi Design，2026-11-04 运行。扫码登录截图连接云端
`https://family.fishdream.xyz:10443`，其余页面使用同步后的本地数据。

## 桌面端（1440 × 1000）

| 页面 | 截图 |
| --- | --- |
| 登录 | [login.png](login.png) |
| 扫码登录（云端，显示 IP 归属城市/设备/有效期） | [login-qr.png](login-qr.png) |
| 家族首页 | [home.png](home.png) |
| 族谱树（全谱） | [tree.png](tree.png) |
| 族谱树（人物侧卡） | [tree-selected.png](tree-selected.png) |
| 成员查询 | [members.png](members.png) |
| 人物档案 | [person.png](person.png) |
| 家族相册 | [gallery.png](gallery.png) |
| 家族故事 | [stories.png](stories.png) |
| 故事阅读页 | [story-detail.png](story-detail.png) |
| 消息 | [messages.png](messages.png) |
| 审核中心 | [requests.png](requests.png) |
| 申请详情（含通过/拒绝） | [request-detail.png](request-detail.png) |
| 我的 | [profile.png](profile.png) |
| 家族管理 | [family.png](family.png) |
| 普通成员首页 | [home-member.png](home-member.png) |

## 移动端（390 × 844）

| 页面 | 截图 |
| --- | --- |
| 家族首页 | [home-mobile.png](home-mobile.png) |
| 扫码登录（移动视口） | [login-qr-mobile.png](login-qr-mobile.png) |
| 族谱树（聚焦中段世代，可拖动） | [tree-mobile.png](tree-mobile.png) |
| 导航抽屉 | [drawer-mobile.png](drawer-mobile.png) |

## 说明

- 照片上传需要服务端配置私有 OBS，本地演示环境未配置，因此相册展示空状态；
  页面的上传、选人、灯箱与错误提示均已实现并走真实接口。
- 演示数据包含 15 位成员、4 篇家族故事、待审核/已通过资料申请与站内通知。
- 云端数据库已拉取并恢复到本地，云端生产数据与本地计数一致（2 用户 / 26 人物 /
  1 故事 / 2 照片，迁移版本 22）。
- 扫码登录页展示请求 IP 归属城市「北京」、Chrome / Windows 设备、IPv6 地址与
  2 分钟倒计时；手机端确认后才签发会话。文档截图中的 IPv6 已脱敏，实际界面显示完整地址。
- 桌面端为完整页面截图，移动端为真实视口截图（不拼接滚动长图）。
- 族谱树截图为 2026-11-03 版本；本次已扩大画布、改为滚轮缩放，并在人物卡上增加
  公历/农历双历、干支年和生肖，树截图尚未重拍。
