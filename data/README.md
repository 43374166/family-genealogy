# data · 首期本地数据（预留）

未来 Go 服务端使用 JSON 文件 + 媒体目录时，运行时数据放在这里：

```text
data/
├── config.json
├── families.json
├── persons.json
├── relationships.json
├── users.json
├── branches.json
├── edit-requests.json
├── audit-logs.json
├── media/
└── backups/
```

注意：

- 数据文件默认不进入 Git（见根目录 `.gitignore`）。
- 正式写入必须经过统一 Repository：互斥写、临时文件、原子替换、备份。
- JSON 损坏时停止写入，不允许自动用空数据覆盖。
- 该目录不是给客户端直接读取的；其他设备必须通过 API 访问服务端。
