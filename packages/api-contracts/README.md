# packages/api-contracts · API 契约

以 [OpenAPI 3.1](openapi.yaml) 作为唯一对外协议来源。

- JSON 字段 camelCase，时间 RFC 3339 UTC，ID 使用 UUID。
- 错误统一为 RFC 9457 `application/problem+json`，客户端依赖稳定的 `code`。
- 人物日期使用 `PartialDate`，允许只到年、农历闰月和族谱原文，不伪造完整日期。
- 分页使用 cursor，不使用会漂移的 offset。
- 认证为不透明会话令牌（Bearer），服务端只存哈希。

当前已落地的是健康检查、迁移和 Go 服务骨架；认证、家庭、人物、树、审核接口按契约逐步实现。
Flutter / React / 小程序不得各自发明关系方向、状态枚举或错误结构。
