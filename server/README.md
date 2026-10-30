# server · Go API + PostgreSQL

多家族族谱后端的第一个可靠基础层。当前包含：

- PostgreSQL 17 schema 与迁移（家庭、账户、成员、人物、家支、父母子女、婚姻、资料申请、审计、会话）。
- Go API 骨架：配置、连接池、请求 ID、结构化日志、panic 恢复、安全响应头、优雅退出。
- `GET /healthz`、`GET /readyz`、`GET /api/v1/meta`。
- Goose 嵌入式迁移，生产作为独立 job 执行，API 启动时不自动迁移。
- 单元测试 + PostgreSQL 约束集成测试 + GitHub Actions。

业务接口尚未实现，契约见 [`packages/api-contracts/openapi.yaml`](../packages/api-contracts/openapi.yaml)，
数据模型说明见 [`docs/backend/data-model.md`](../docs/backend/data-model.md)。

## 本地运行

要求 Go 1.25+ 和 PostgreSQL 17（或 Docker）。

```bash
cd server
cp .env.example .env
# 修改 .env 中 DATABASE_URL / POSTGRES_PASSWORD，然后加载环境变量
```

Windows PowerShell 示例：

```powershell
$env:DATABASE_URL = "postgres://familytree:change-me@localhost:5432/familytree?sslmode=disable"
go run ./cmd/migrate up
go run ./cmd/api
```

Docker Compose（会先跑迁移，再启动 API）：

```bash
cd server
cp .env.example .env
docker compose up --build
```

## 检查

```bash
gofmt -w cmd internal
go vet ./...
go test ./...
```

带 PostgreSQL 约束测试：

```powershell
$env:TEST_DATABASE_URL = "postgres://familytree:change-me@localhost:5432/family_tree_test?sslmode=disable"
go test -race ./...
```

集成测试只在设置 `TEST_DATABASE_URL` 时运行；目标数据库需先执行 `go run ./cmd/migrate up`，
并且必须是可丢弃的测试库（测试会留下测试数据）。

## 设计约束

- 所有业务表带 `family_id`，跨家族关系由复合外键在数据库层拒绝。
- 父母子女关系有自环、重复和环路触发器；同族关系写入使用 advisory lock 串行化。
- 人物生卒日期使用年/月/日分量 + 公历/农历 + 闰月 + 原文，不伪造完整日期。
- `edit_requests` 与正式写入必须在同一事务中完成；审计日志只追加。
- 生产必须 TLS 连接数据库、迁移账号与运行账号分离、每日全量备份 + WAL 归档。
- 不把 `DATABASE_URL` 写入日志；不提交 `.env`。
