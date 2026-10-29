# apps/web · React 网页端（尚未开始）

计划使用 **React + TypeScript + Vite**，包含两个共享 API 客户端与类型定义的入口：

- 成员端：`/`、`/tree`、`/persons/:id`、`/requests`、`/profile`
- 后台管理：`/admin/dashboard`、`/admin/persons`、`/admin/branches`、`/admin/reviews`、
  `/admin/settings`

成员端与后台使用不同路由、布局和权限菜单，但共用同一后端 API，不复制业务后端。

当前优先完成 Flutter 移动端原型，此目录暂不创建脚手架，避免多端同时产生未验证代码。
