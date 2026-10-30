# 运维手册

## 登录会话

- App 登录成功后把会话令牌存入 Android Keystore / iOS Keychain（`flutter_secure_storage`）。
- 启动时自动恢复会话；每次已登录请求都会把服务端会话有效期滑动延长到 30 天。
- 主动退出会撤销服务端会话并清除本机令牌；令牌失效（401）时自动清除并回到登录页。

## 数据库备份

服务器每日 **03:30（Asia/Shanghai）** 执行：

```text
/usr/local/sbin/familytree-backup
```

- 输出目录：`/var/backups/familytree/`
- 保留最近 14 份，`latest.sql.gz` 指向最新备份
- 同时生成 `.sha256`
- 使用 `mysqldump --single-transaction`，包含表结构和数据、触发器、存储过程

系统单元：

```text
familytree-backup.service
familytree-backup.timer
```

查看状态：

```bash
systemctl list-timers familytree-backup.timer
journalctl -u familytree-backup.service -n 50
```

## 异地副本

Windows 任务计划 `FamilyTreeBackupPull` 每日 **04:10** 从服务器拉取最新备份到本地
`backups/`，保留 30 天；脚本为 `scripts/pull-familytree-backup.ps1`。电脑关机时会跳过，
下一次开机后任务计划可继续执行。

## 校验备份

```bash
/usr/local/sbin/familytree-restore /var/backups/familytree/latest.sql.gz
```

该命令把备份恢复到临时库并打印人员、关系、用户、审计行数，验证后自动删除临时库。

## 生产恢复（破坏性）

先确认备份文件时间，再执行：

```bash
CONFIRM_RESTORE=YES /usr/local/sbin/familytree-restore --production /var/backups/familytree/latest.sql.gz
```

脚本会先停 API、再打一份安全备份，然后恢复并重启 API。恢复期间服务不可用。

## 日常检查

- `/readyz` 返回数据库正常
- 每日备份文件体积没有突然变成 0
- 本地 `backups/` 有当天文件且校验通过
- 审计日志只追加，不修改历史
