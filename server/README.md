# server · Go API + MySQL

多家族族谱后端的可靠基础层。**运行库为 MySQL 8.4 LTS**；PostgreSQL 17 的 DDL
保留为设计参考，不参与默认运行。

当前包含：

- MySQL 8.4 schema 与迁移：家庭、账户、成员、人物、家支、父母子女、婚姻、资料申请、审计、会话。
- Go API 骨架：配置、`database/sql` 连接池、请求 ID、结构化日志、panic 恢复、安全响应头、优雅退出。
- `GET /healthz`、`GET /readyz`、`GET /api/v1/meta`。
- Goose 嵌入式迁移；生产作为独立 job 执行，API 启动时不自动迁移。
- 单元测试 + MySQL 约束集成测试 + 真实 MySQL 8.4 CI。
- PostgreSQL 17 设计保留在 [`internal/database/migrations/postgres/00001_init.sql`](internal/database/migrations/postgres/00001_init.sql)，
  CI 会用干净 PostgreSQL 17 验证该参考设计。

已经实现的 API：

- `POST /api/v1/auth/login`（Argon2id 密码校验，返回 30 天不透明会话令牌）
- `POST /api/v1/auth/register`（邀请码注册，手机号字段可选）
- `POST /api/v1/auth/sms/send`、`POST /api/v1/auth/sms/login`（手机号验证码登录）
- `POST /api/v1/auth/phone/send`、`POST /api/v1/auth/phone/bind`（登录后绑定手机号）
- `POST /api/v1/auth/logout`
- `GET /api/v1/invites`、`POST /api/v1/invites`（仅 owner；可邀请普通成员或指定家支的分支管理员）
- `POST /api/v1/bind-requests`（成员申请绑定族谱人物）
- `GET /api/v1/bind-requests?status=&mine=`
- `POST /api/v1/bind-requests/{requestId}/approve|reject`
- `GET /api/v1/accounts`、`GET|POST /api/v1/branch-admins`、`DELETE /api/v1/branch-admins/{grantId}`（owner 任免）
- `GET /api/v1/me`
- `GET /api/v1/family`
- `GET /api/v1/tree?generation=&branchId=`
- `GET /api/v1/persons?q=&generation=&branchId=&cursor=&limit=`
- `POST /api/v1/persons`（owner/admin 直接新增人物）
- `PATCH /api/v1/persons/{personId}`（owner/admin 直接编辑资料，带版本冲突保护）
- `GET /api/v1/persons/{personId}`
- `GET /api/v1/branches`
- `POST /api/v1/relationships/parent-child`
- `DELETE /api/v1/relationships/parent-child/{edgeId}`
- `POST /api/v1/relationships/spouse`
- `DELETE /api/v1/relationships/spouse/{edgeId}`
- `POST /api/v1/edit-requests`（提交人物资料修改申请，限籍贯/职业等字段）
- `POST /api/v1/edit-requests/profile`（成员提交完整资料修改申请，审核时事务应用）
- `POST /api/v1/edit-requests/write`（成员提交新增人物/父母子女/配偶申请）
- `GET /api/v1/edit-requests?status=&mine=&limit=`
- `GET /api/v1/edit-requests/{requestId}`
- `POST /api/v1/edit-requests/{requestId}/approve`
- `POST /api/v1/edit-requests/{requestId}/reject`

资料申请只允许修改籍贯、现居地、职业、教育和生平；审核通过时在事务内更新
`persons` 并追加 `audit_logs`。owner/admin 可新增人物和父母子女/配偶关系，
服务端校验世代、重复角色、配偶同代和父母子女环路。普通成员的新增人物/关系写入走
`/edit-requests/write`，审核通过时在同一事务应用。邀请码注册走
`/auth/register`，绑定人物走 `bind-requests`，通过后写入 `family_memberships.person_id`。
分支管理员由 owner 通过邀请码指定家支，或在“分支管理员”页任命已有成员；默认含
下级支。owner/admin 可直接编辑人物姓名、性别、世代、家支、生卒、籍贯、职业、教育和
生平，并可删除错误亲属关系后重新添加；删除关系只删关系边，不删除人物。管理员只能
审核本支范围内的写入/绑定申请和直接写入；撤销最后一个授权后自动
降为普通成员。邀请码创建仍仅限 owner。手机号验证码登录已接入华为云消息&短信
（MSGSMS）SDK；需要配置应用 app_key/app_secret、通道号、签名和验证码模板，未配置时
返回 `SMS_UNAVAILABLE`。照片上传、刷新令牌和登录限流尚未实现。
契约见 [`packages/api-contracts/openapi.yaml`](../packages/api-contracts/openapi.yaml)，
数据模型说明见 [`docs/backend/data-model.md`](../docs/backend/data-model.md)。

## 演示数据

迁移后执行一次：

```powershell
$env:DATABASE_DSN = "familytree:change-me@tcp(127.0.0.1:3306)/familytree?parseTime=true&loc=UTC&charset=utf8mb4&collation=utf8mb4_0900_ai_ci"
go run ./cmd/seed
```

演示账号：`linglei / Demo#2026`（仅本地演示，上线前必须移除或改密）。
种子会写入 1 个家族、5 个家支、15 个人物和对应关系；重复执行会检测并跳过。

## 本地运行（不用 Docker）

要求 Go 1.25+ 和本机 MySQL 8.4 LTS（MySQL 8.0.35 也已验证兼容）。

先创建数据库和应用账号：

```sql
CREATE DATABASE familytree CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
CREATE USER 'familytree'@'%' IDENTIFIED BY 'change-me';
GRANT ALL PRIVILEGES ON familytree.* TO 'familytree'@'%';
```

迁移会创建触发器和检查约束。如果 MySQL 开启了 binary logging，迁移账号需要
`SUPER`（或服务端设置 `log_bin_trust_function_creators=1`）；运行 API 的账号不需要
这个权限。生产建议单独使用受控迁移账号。

Windows PowerShell：

```powershell
$env:DATABASE_DSN = "familytree:change-me@tcp(127.0.0.1:3306)/familytree?parseTime=true&loc=UTC&charset=utf8mb4&collation=utf8mb4_0900_ai_ci"
go run ./cmd/migrate up
go run ./cmd/api
```

Docker Compose 是可选方案；`compose.yaml` 已切到 MySQL 8.4，并在开发环境关闭
binary log，方便受限账号执行迁移。

## 检查

```bash
gofmt -w cmd internal
go vet ./...
go test ./...
```

带 MySQL 约束测试：

```powershell
$env:TEST_DATABASE_DSN = "familytree:change-me@tcp(127.0.0.1:3306)/family_tree_test?parseTime=true&loc=UTC&charset=utf8mb4&collation=utf8mb4_0900_ai_ci"
go test -race ./...
```

集成测试只在设置 `TEST_DATABASE_DSN` 时运行；目标数据库需先迁移，并且必须是可丢弃的
测试库（测试会留下测试数据）。

## 设计约束

- 所有业务表带 `family_id`，跨家族关系由复合外键在数据库层拒绝。
- MySQL 没有部分唯一索引，使用生成列 + 唯一索引实现“一个活跃 owner / 一个活跃父/母 / 一个活跃账户人物”。
- 父母子女关系有自环、重复和顺序环路触发器；并发写关系时，业务层仍需在事务内串行化同族写入。
- 人物生卒日期使用年/月/日分量 + 公历/农历 + 闰月 + 原文；完整日期校验由业务层补齐。
- `edit_requests` 与正式写入必须在同一事务中完成；审计日志只追加。
- 生产必须 TLS 连接 MySQL、迁移账号与运行账号分离、每日全量备份 + binlog 归档。
- 不把 `DATABASE_DSN` 写入日志；不提交 `.env`。
