package store

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/model"
)

func (s *Store) ListActivities(ctx context.Context, familyID string, limit int) ([]model.Activity, error) {
	if limit < 1 || limit > 50 {
		limit = 20
	}
	rows, err := s.db.QueryContext(ctx, `
		SELECT a.id, a.action, a.entity_type, a.after_data, a.created_at,
		       COALESCE(u.display_name, '系统')
		FROM audit_logs a
		LEFT JOIN users u ON u.id = a.actor_user_id
		WHERE a.family_id = ?
		ORDER BY a.created_at DESC, a.id DESC
		LIMIT ?`, familyID, limit)
	if err != nil {
		return nil, fmt.Errorf("list activity: %w", err)
	}
	defer rows.Close()
	items := make([]model.Activity, 0, limit)
	for rows.Next() {
		var (
			item       model.Activity
			entityType string
			after      []byte
		)
		if err := rows.Scan(
			&item.ID, &item.Action, &entityType, &after,
			&item.CreatedAt, &item.ActorName,
		); err != nil {
			return nil, fmt.Errorf("scan activity: %w", err)
		}
		item.Summary, item.Kind, item.NeedsReview = activityLabel(item.Action)
		item.Detail = activityDetail(item.Action, entityType, after)
		items = append(items, item)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate activity: %w", err)
	}
	return items, nil
}

func activityLabel(action string) (summary, kind string, needsReview bool) {
	switch action {
	case "person.created":
		return "新增了人物", "person", false
	case "person.updated":
		return "更新了人物资料", "person", false
	case "relationship.parent_child.created":
		return "新增了亲子关系", "person", false
	case "relationship.spouse.created":
		return "新增了配偶关系", "person", false
	case "relationship.deleted":
		return "删除了亲属关系", "person", false
	case "family.created":
		return "创建了家族", "family", false
	case "family.imported":
		return "导入了旁支数据", "family", false
	case "member.joined":
		return "加入了家族", "member", false
	case "member.registered":
		return "注册并创建了家族", "member", false
	case "binding.requested":
		return "提交了人物绑定申请", "request", true
	case "binding.approved":
		return "通过了人物绑定", "request", false
	case "binding.rejected":
		return "驳回了人物绑定", "request", false
	case "edit_request.approved":
		return "审核通过了资料修改", "request", false
	case "edit_request.rejected":
		return "驳回了资料修改", "request", false
	case "branch_admin.granted":
		return "设置了分支管理员", "member", false
	case "branch_admin.revoked":
		return "取消了分支管理员", "member", false
	case "user.phone_bound":
		return "绑定了手机号", "member", false
	case "import_package.created":
		return "生成了数据导入码", "family", false
	default:
		return "更新了家族资料", "system", false
	}
}

func activityDetail(action, entityType string, after []byte) string {
	data := map[string]any{}
	if len(after) > 0 {
		_ = json.Unmarshal(after, &data)
	}
	for _, key := range []string{
		"fullName", "personName", "rootName", "sourceFamilyName",
		"branchName", "displayName",
	} {
		if value, ok := data[key].(string); ok && strings.TrimSpace(value) != "" {
			switch key {
			case "sourceFamilyName":
				return "来源：" + value
			case "branchName":
				return "家支：" + value
			default:
				return value
			}
		}
	}
	switch entityType {
	case "person":
		return "人物资料"
	case "family_import":
		return "旁支数据包"
	case "family":
		return "家族资料"
	case "user":
		return "成员账号"
	default:
		return ""
	}
}
