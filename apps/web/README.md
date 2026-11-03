# apps/web · React 成员端

家族族谱 Web 成员端，面向已登录的家族成员使用。与 Flutter / HarmonyOS 共用同一套
Go API；成员端与未来的独立后台管理端共用类型与请求层，不再复制业务后端。

当前不是静态演示页：账号密码 / 手机 App 扫码登录、首页统计、族谱树、成员查询、
人物档案、资料申请/审核、家族故事、消息、家族资料与家支、邀请码、字辈都已经接入
真实接口。扫码登录会展示本次请求的 IP、归属城市和浏览器设备，由手机端确认后才签发
会话。照片上传依赖服务端配置私有 OBS，本地未配置时会返回 `PHOTOS_UNAVAILABLE`
（页面会给出对应提示）。

## 技术栈

| 层 | 选型 |
| --- | --- |
| 框架 | React 18 + TypeScript 5.8 |
| 构建 | Vite 7 |
| 路由 | react-router-dom 7 |
| 状态 | Redux Toolkit + react-redux |
| UI | 抖音 Semi Design（`@douyinfe/semi-ui` / `semi-icons`） |
| 请求 | axios，统一扁平请求层 |
| 扫码 | `qrcode.react`（SVG 二维码） |
| 农历 | `lunar-typescript`（公历/农历互转、干支、生肖） |
| 族谱图 | `@xyflow/react`（React Flow 12）+ `@dagrejs/dagre` |
| 字体 | Noto Serif SC（`@fontsource`，按 unicode range 加载） |
| 测试 | Vitest（Dagre 家庭单元布局） |

## 页面与路由

| 路由 | 页面 | 说明 |
| --- | --- | --- |
| `/login` | 登录 | 水墨展卷双栏布局；账号密码 / 扫码登录双模式，二维码 2 分钟有效 |
| `/register` | 注册 | 邀请码加入家族，或直接创建个人家族 |
| `/` | 家族首页 | 家族概览、快捷入口、纪念日、待审核、最新动态、最近故事 |
| `/tree` | 族谱树 | Dagre 家庭单元布局 + React Flow 交互；世代/家支筛选、搜索定位、人物侧卡 |
| `/members` | 成员查询 | 姓名/字号/别名搜索，世代/家支筛选，游标分页，新增成员 |
| `/persons/:personId` | 人物档案 | 生平、亲属、照片、故事；管理员直接编辑，普通成员提交资料申请 |
| `/gallery` | 家族相册 | 照片墙、成员筛选、灯箱、上传（需要服务端 OBS） |
| `/stories` | 家族故事 | 卷首故事 + 故事卡片、搜索、新建 |
| `/stories/:storyId` | 故事详情 | 阅读版式、配图灯箱、编辑/删除 |
| `/messages` | 消息 | 未读数、全部已读、按目标跳转审核/合并页面 |
| `/requests` | 审核中心 / 我的申请 | 按角色切换；逐字段差异、通过/拒绝、审核记录 |
| `/profile` | 我的 | 人物档案入口、我的申请、家族空间、切换家族、账号安全 |
| `/family` | 家族管理 | 家族资料、家支、账号角色、邀请码、字辈（族长/管理员） |

未登录访问任意受保护页面会跳转 `/login`，登录后回到原路径；普通成员访问 `/family`
会被重定向到首页。

## 目录

```text
src/
├── api/                  # auth / family / persons / content 四个领域接口模块
├── components/           # 头像、鉴权图片、表单抽屉、状态胶囊、空/错状态等
├── hooks/                # useAsync、useAuthedImage、useDebounce、useMediaQuery
├── layouts/              # AppShell、导航定义、响应式侧栏/抽屉/底栏
├── pages/
│   ├── auth/             # 登录、注册、水墨展卷布局
│   ├── home/             # 家族首页
│   ├── tree/             # treeLayout.ts（纯函数）、TreeNodes.tsx、TreePage.tsx
│   ├── members/          # 成员查询
│   ├── person/           # 人物档案
│   ├── gallery/          # 家族相册
│   ├── stories/          # 故事列表 + 详情
│   ├── messages/         # 消息中心
│   ├── requests/         # 审核中心 / 我的申请
│   ├── profile/          # 我的
│   └── family/           # 家族管理
├── routes/guards.tsx     # RequireAuth / GuestOnly / RequireReviewer
├── store/                # authSlice / notificationSlice / uiSlice
├── styles/               # 设计变量、纸本主题、Semi 主题覆写
├── types/api.ts          # 与服务端字段严格一致的领域类型
└── utils/                # request（扁平请求）、storage、format、error、cn
```

## 本地运行

开发服务器默认把 `/api` 代理到云端 API：

```text
https://family.fishdream.xyz:10443
```

```powershell
cd apps/web
pnpm install
pnpm dev
# http://127.0.0.1:5173
```

云端当前对外可用的 HTTPS 端口是 **10443**；`10433` 未监听，连接会超时。
如需改回本机 Go 服务，复制 `.env.example` 为 `.env.local`，把
`VITE_PROXY_TARGET` 改成 `http://127.0.0.1:8080`，并在 `server` 目录启动
`go run ./cmd/api`。不需要代理时，直接把 `VITE_API_BASE_URL` 设为完整 API 前缀。

### 环境变量

复制 `.env.example` 为 `.env.local`（仓库不提交 `.env.*`）：

```dotenv
VITE_API_BASE_URL=/api/v1
VITE_PROXY_TARGET=https://family.fishdream.xyz:10443
VITE_SOURCE_MAP=false
```

- `VITE_API_BASE_URL`：axios 的 baseURL；生产默认同源 `/api/v1`。
- `VITE_PROXY_TARGET`：仅开发服务器代理目标；默认云端 10443，可覆盖为本地 8080。
- 图片内容路径是 `/api/v1/photos/{id}/content`，必须带 Bearer，因此页面不使用裸
  `<img src>`，而是由 `useAuthedImage` 拉 Blob 后渲染 object URL。

### 生产构建

```powershell
pnpm typecheck
pnpm test
pnpm build
```

把 `dist/` 部署到 Nginx，并保证：

```nginx
location / {
  try_files $uri $uri/ /index.html;
}

location /api/ {
  proxy_pass http://127.0.0.1:8080;
  proxy_set_header Host $host;
  proxy_set_header X-Real-IP $remote_addr;
  proxy_set_header X-Forwarded-Proto $scheme;
}
```

`BrowserRouter` 需要 SPA fallback；API 和 Web 推荐同域，避免额外 CORS 配置。

## 请求层

参考 `D:/fishdream/md2card` 的请求组织方式，请求层保持“HTTP 不抛、业务显式分支”：

- `flatRequest<T>()` 返回 `{ data, error, status }`，错误统一归一化为 `ApiError`；
- 默认按 RFC 9457 `detail → title → HTTP 状态` 提取中文提示，并只弹一次 Toast；
- `skipAuth` 用于登录/注册；`skipErrorToast` 用于页面自行呈现的错误；
- 请求头自动注入 `Authorization` 和 `X-Request-Id`；
- 401 只触发一次全局 `auth:expired` 事件，由 `App` 清空会话并跳转登录；
- 页面通过 `request<T>()` 拿到解包后的数据，失败时抛出 `ApiError`；
- 图片请求走独立的鉴权 Blob 客户端，`useAuthedImage` 负责缓存与 object URL。

## 扫码登录

Web 登录页切换到「扫码登录」后调用 `POST /api/v1/auth/qr` 创建一次性会话：

1. 服务端生成 `familytree://web-login?id=...&secret=...`，数据库只存 secret 的
   SHA-256 哈希，并把请求 IP、IP 归属城市、浏览器/设备标签一并记录；
2. 手机 App 在「我的」右上角「扫一扫」扫描二维码（与邀请码共用入口，按
   `familytree://web-login` 协议分流），先调用 `.../scan`，确认页展示电脑所在城市、
   IP 和设备；
3. 用户点击「确认登录网页版」后调用 `.../confirm`；
4. Web 每 2 秒轮询 `GET /api/v1/auth/qr/{id}?secret=...`，只有第一次确认后的轮询会
   拿到正常登录会话；之后同一二维码再轮询返回 `QR_ALREADY_USED`，避免重放；
5. 二维码 2 分钟过期；切换登录方式、刷新或离开页面会调用 `.../cancel`。

归属地由服务端 `ip-api.com` 按 `X-Real-IP` 查询，写入二维码会话；查询失败时展示
「IP 归属地查询中 / 未知」，不会阻塞登录。Nginx 必须透传 `X-Real-IP`。

## 族谱树布局

`src/pages/tree/treeLayout.ts` 是纯函数，不依赖 React：

1. 用并查集把「非离婚配偶」聚合成家庭单元；每个单元最多包含一位本姓成员与多位配偶；
2. 家庭单元作为 Dagre 节点，父母子女关系作为边，Dagre 计算同一层级内的 x 顺序；
3. 最终 y 仍按真实 `generationNo` 排列，覆盖 Dagre 的 rank，避免婚姻边扰乱世代；
4. 同世代单元按 x 排开，消除孤立家庭单元重叠；
5. 夫妻并排渲染，父代到子代只从家庭单元中轴落下一条连线。

这也避免了「父母各画一条线到子女」的重复连接。React Flow 只负责缩放、拖动、定位和
自定义节点渲染；节点内部仍渲染真实人物卡片，点击打开人物侧卡。

树页面占满顶栏以下的可用视口，页面本身不产生纵向滚动；画布填满剩余高度。滚轮直接
缩放（`panOnScroll=false`），拖动画布使用鼠标拖拽。首次进入会聚焦当前成员的家庭单元，
避免把 20+ 人的全谱压成不可读的缩略图，「查看全谱」仍可查看全局。

人物卡片扩大到 208×142，默认展示：

- 姓名、性别、在世/已故、生卒年、世代/字辈、生肖；
- 生卒日期同时给出记录日历与另一日历；
- 例：`农历 丙戌年八月十四 / 公历 1946.09.09`、`农历 甲辰年腊月十二 / 公历 2025.01.11`。

`src/utils/calendar.ts` 负责转换，支持闰月、缺月/缺日和历史日期；无法换算时保留原文，
不猜测。人物侧卡与完整档案页复用同一份双历结果。

## 当前边界

- 图片上传/头像裁剪依赖服务端 OBS 和签名上传链路；Web 已做真实请求和错误分支，
  本地未配置 OBS 时不能完成上传。
- 短信验证码、家族合并审核、导出等复杂能力仍以移动端/HarmonyOS 为主；Web 已支持
  账号密码与手机 App 扫码两种登录方式，家族合并通知暂时落到「我的」。
- 审核中心覆盖资料修改、完整资料修改、新增人物、父母子女、配偶和关系解除申请的
  字段展示与通过/拒绝；绑定申请暂未单独做成 Web 审核页。
- 独立的 `/admin` 后台管理端尚未拆分；当前 `/family` 已覆盖族长/管理员日常维护。

## 验收记录

2026-11-04：

- `pnpm typecheck`、`pnpm lint` 通过；
- `pnpm test`：11 项测试全部通过（6 项 Dagre 布局 + 5 项公历/农历互转、闰月与生肖）；
- `pnpm build` 通过；
- 使用 Chromium 完成账号密码登录、**扫码登录全流程**（二维码生成 → 手机接口扫码
  → 确认 → 浏览器自动登录）、首页、族谱树选中/定位、成员/人物、故事详情、审核详情、
  暗色主题、普通成员权限、移动端抽屉与树聚焦的真实浏览器走查；
- 族谱树实测：1440×1000 视口下页面 `scrollHeight=1000`、画布高 705px；滚轮缩放生效，
  人物卡片同时显示双历与生肖；1366×768 视口同样无页面纵向滚动；
- 扫码截图使用云端 API，页面显示请求 IP 归属城市「北京」；
- 截图见 [`docs/screenshots/web`](../../docs/screenshots/web/README.md)。
