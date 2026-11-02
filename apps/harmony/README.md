# 家族族谱 · HarmonyOS（原生 ArkTS/ArkUI）

这是一个独立的 HarmonyOS NEXT 原生客户端，不是 Flutter 套壳。首个版本聚焦登录、首页、族谱树、成员查询、人物档案、新增人物和删除人物，直接连接现有 Go API。

## 已实现

- 登录与服务器地址切换，默认线上 `https://family.fishdream.xyz:10443`
- 线上域名只有 IPv6 记录；登录页可切“家庭局域网” (`http://192.168.1.36:10080/family-api`)，解析失败时会自动回退一次
- 登录态持久化（PersistentStorage）
- 首页：家族名称/家风、成员与家支统计、快捷入口、近期生日与祭日、最新动态
- 族谱树：
  - 原生 ArkUI 卡片 + Canvas 连线
  - 配偶并排显示
  - 父亲、母亲都从各自卡片中心接入共同子女横线
  - 不同配偶的子女横线分层错开
  - 横向/纵向滚动查看，点击人物打开档案
- 成员查询：姓名/世代搜索
- 人物档案：父母、配偶、子女、生卒与生平
- 新增人物：姓、名、性别、世代、家支
- 删除人物：族长/管理员可见，服务端软删除
- 家族相册：网格、鉴权图片加载、全屏查看、按人物筛选、多选上传、删除
- 头像：系统相册选图、中心方形裁剪（可缩放）、上传/移除，人物档案内显示头像
- 家族故事：故事列表、详情、新建（标题/正文/关联人物/最多 9 张配图）、作者或族长删除
- 消息中心：通知列表、未读数、单条/全部已读
- 资料与绑定审核：族长/管理员查看待审的资料修改和人物绑定申请，填写意见后通过或拒绝
- 家族合并：合并申请列表、详情，选择人物/故事/照片、目标家支、起始世代和挂靠父辈；族长通过或拒绝
- 数据导入导出：导出完整家族 JSON、生成旁支导入码、输入导入码预览并选择家支/世代/父辈导入
- 我的：账号、服务器、退出登录

## 尚未对齐 Android 版

- 相册多人关联、拍摄时间/说明编辑、上传前压缩
- 故事编辑（修改已有故事）、故事图片全屏查看
- 审核申请的逐字段差异详情、消息点击跳转目标页面
- 成员管理、邀请码
- 推送通知
- 扫码/邀请

这些能力不影响当前版本的族谱、相册、故事、消息、审核、合并和数据迁移，后续按模块补齐。

## 构建

本机使用 DevEco Studio 26.0 / HarmonyOS SDK API 26 验证通过。

```powershell
$env:JAVA_HOME='D:\install\DevEco Studio\jbr'
$env:DEVECO_SDK_HOME='D:\install\DevEco Studio\sdk'
$env:DEVECO_HOME='D:\install\DevEco Studio'
$env:PATH='D:\install\DevEco Studio\tools\node;D:\install\DevEco Studio\tools\ohpm\bin;D:\install\DevEco Studio\tools\hvigor\bin;' + $env:PATH
hvigorw.bat --mode module -p module=entry@default -p product=default -p buildMode=release assembleHap --no-daemon
```

产物：

```text
entry/build/default/outputs/default/entry-default-unsigned.hap
```

### 签名

仓库不提交开发者证书，因此构建产物是 **unsigned HAP**。用 DevEco Studio 打开 `apps/harmony`：

1. File → Project Structure → Signing Configs；
2. 勾选 Automatically generate signature 或选择自己的证书；
3. 重新 Build → Build Hap(s)/APP(s)；
4. 通过 hdc 安装到真机/模拟器。

`hdc install entry-default-signed.hap`。

## 目录

```text
apps/harmony/
├── AppScope/                 # 应用级配置和图标
├── entry/src/main/ets/
│   ├── entryability/         # UIAbility
│   ├── model/
│   │   ├── Types.ets         # API 数据模型
│   │   └── TreeLayout.ets    # 族谱布局与连线计算
│   ├── components/AuthImage.ets # 带鉴权的图片加载
│   ├── service/ApiClient.ets # HTTP、图片和 multipart 上传
│   └── pages/Index.ets       # 登录/首页/树/成员/档案/相册/新增/我的
├── entry/src/main/resources/ # 图片、颜色、文案、页面清单
└── build-profile.json5
```

## 说明

- 鸿蒙端的树布局与 Android 0.47.4 的规则一致：每对夫妻一条共同子女横线，父母双方均从卡片中心接入。
- 当前 bundleName 为 `cn.familytree.harmony`，版本 `1.5.0`。
- 相册上传暂按当前筛选人物关联；头像裁剪目前是“中心正方形 + 缩放”，没有自由拖动取景框。
- **找不到请求主机名字 / Could not resolve host**：`family.fishdream.xyz` 当前只解析到 IPv6。设备没有 IPv6 时，在登录页点“家庭局域网”，或直接填 `http://192.168.1.36:10080/family-api`。该 HTTP 入口只允许内网地址访问，离开家庭 Wi-Fi 后请切回线上服务器。
- 未签名的 HAP 不能直接安装，这是 DevEco/HarmonyOS 的签名要求，不是应用代码问题。
