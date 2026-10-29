# server · Go REST API（尚未开始）

按照当前约定，本阶段**不写后端**。此目录只保留位置和边界说明，避免 Flutter 原型
把服务端职责揉进客户端。

## 规划技术栈

- Go + REST API
- 首期 JSON Repository，预留 SQLite / PostgreSQL
- 统一响应结构与错误码
- 认证、家支授权、审核状态机、审计日志、媒体文件校验
- 备份、原子写入、版本冲突检测

## 建议目录（后续创建）

```text
server/
├── cmd/api/
├── internal/
│   ├── auth/
│   ├── family/
│   ├── person/
│   ├── relationship/
│   ├── review/
│   ├── media/
│   ├── audit/
│   └── storage/
├── api/
└── tests/
```

## 最小 API 起点

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/v1/auth/login` | 登录并发放会话 / Token |
| GET | `/api/v1/families/{familyId}` | 家族概览 |
| GET | `/api/v1/persons?generation=&branchId=&q=` | 成员查询 |
| GET | `/api/v1/persons/{id}` | 人物档案 |
| GET | `/api/v1/relationships/tree` | 族谱树数据 |
| POST | `/api/v1/edit-requests` | 提交资料修改申请 |
| GET | `/api/v1/edit-requests/mine` | 我的申请 |
| POST | `/api/v1/edit-requests/{id}/review` | 审核（仅族长 / 授权管理员） |

## 安全底线

- 不能以前端隐藏按钮替代服务端授权。
- 审核人不能通过篡改 `personId` / `branchId` 绕过范围校验。
- 正式写入记录操作者、时间、变更前后摘要。
- 任何文件上传都必须校验真实类型、大小并重命名。
- JSON 损坏时停止写入，禁止用空数据覆盖。

数据只在本机时，手机和其他设备必须通过这台电脑的 API 访问，不能直接读取其本地文件。
