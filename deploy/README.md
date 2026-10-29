# deploy · 部署（预留）

首期建议：

- Flutter 客户端不监听固定端口，主动请求 API。
- Go API 示例端口 `8080`。
- React 开发服务器 `5173`；生产由 Nginx 托管静态文件并反向代理 API。
- 局域网测试使用服务器电脑的局域网 IP，不能用手机自身的 `localhost`。
- 正式远程访问启用 HTTPS、防火墙和最小权限。

后续再补充 `nginx/` 与 `docker-compose.yml`，当前不提前引入未验证的部署配置。
