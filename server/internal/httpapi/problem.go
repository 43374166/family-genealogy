package httpapi

import (
	"encoding/json"
	"net/http"
	"strings"
	"unicode"

	chimw "github.com/go-chi/chi/v5/middleware"
)

const problemContentType = "application/problem+json; charset=utf-8"

type FieldError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

// Problem is RFC 9457 Problem Details. Clients switch on the stable Code field,
// never on human-readable prose.
type Problem struct {
	Type      string       `json:"type"`
	Title     string       `json:"title"`
	Status    int          `json:"status"`
	Detail    string       `json:"detail,omitempty"`
	Instance  string       `json:"instance,omitempty"`
	Code      string       `json:"code"`
	RequestID string       `json:"requestId,omitempty"`
	Errors    []FieldError `json:"errors,omitempty"`
}

func writeProblem(w http.ResponseWriter, r *http.Request, status int, code, detail string) {
	p := Problem{
		Type:      "https://family-tree.local/problems/" + strings.ToLower(code),
		Title:     problemTitle(status),
		Status:    status,
		Detail:    localizeProblemDetail(detail),
		Instance:  r.URL.Path,
		Code:      code,
		RequestID: chimw.GetReqID(r.Context()),
	}
	writeJSONStatus(w, status, problemContentType, p)
}

// problemTitle keeps the RFC 9457 title human readable for Chinese clients.
func problemTitle(status int) string {
	if title, ok := problemTitles[status]; ok {
		return title
	}
	return "请求失败"
}

var problemTitles = map[int]string{
	http.StatusBadRequest:            "请求参数不正确",
	http.StatusUnauthorized:          "请先登录",
	http.StatusForbidden:             "没有操作权限",
	http.StatusNotFound:              "内容不存在",
	http.StatusMethodNotAllowed:      "请求方式不被允许",
	http.StatusGone:                  "内容已失效",
	http.StatusConflict:              "数据冲突",
	http.StatusRequestEntityTooLarge: "文件太大",
	http.StatusUnsupportedMediaType:  "不支持的文件类型",
	http.StatusUnprocessableEntity:   "提交内容不符合要求",
	http.StatusTooManyRequests:       "操作太频繁",
	http.StatusInternalServerError:   "服务器内部错误",
	http.StatusBadGateway:            "上游服务异常",
	http.StatusServiceUnavailable:    "服务暂不可用",
}

// localizeProblemDetail translates the small fixed vocabulary of API problem
// details. Machine-readable clients still switch on Code; this only keeps the
// human-readable message Chinese everywhere in the app.
func localizeProblemDetail(detail string) string {
	if detail == "" {
		return detail
	}
	if translated, ok := problemDetails[detail]; ok {
		return translated
	}
	hasChinese := false
	hasLatin := false
	for _, value := range detail {
		if unicode.Is(unicode.Han, value) {
			hasChinese = true
		}
		if value >= 'A' && value <= 'Z' || value >= 'a' && value <= 'z' {
			hasLatin = true
		}
	}
	if !hasChinese && hasLatin {
		// Safety net: a newly introduced English detail must never leak into
		// the Chinese client UI.
		return "请求未完成，请稍后重试"
	}
	return detail
}

var problemDetails = map[string]string{
	"a rejection note is required":                                "拒绝申请时必须填写原因",
	"a valid import code is required":                             "请输入有效的导入码",
	"a valid invite code is required":                             "请输入有效的邀请码",
	"a valid qr secret is required":                               "扫码凭证无效，请刷新二维码",
	"qr login is unavailable":                                     "扫码登录暂不可用",
	"qr login not found":                                          "二维码已失效，请刷新",
	"qr login expired":                                            "二维码已过期，请刷新",
	"qr login is no longer available":                             "二维码状态已变化，请刷新",
	"qr login already used":                                       "二维码已使用，请刷新",
	"too many qr login attempts":                                  "扫码登录操作过于频繁，请稍后再试",
	"account has no active family":                                "账号尚未加入任何家族",
	"account is not active":                                       "账号已被停用",
	"avatar must be at most 5 MB":                                 "头像不能超过 5 MB",
	"baseVersion must be positive":                                "资料版本号必须大于 0",
	"caption is too long":                                         "照片说明太长",
	"code and branchId are required":                              "导入码和家支不能为空",
	"could not read avatar":                                       "读取头像失败，请稍后重试",
	"could not read file":                                         "读取文件失败，请重新选择",
	"could not read photo":                                        "读取照片失败，请稍后重试",
	"could not store avatar":                                      "保存头像失败，请稍后重试",
	"could not store photo":                                       "保存照片失败，请稍后重试",
	"current password is incorrect":                               "当前密码不正确",
	"database is not configured":                                  "数据库尚未配置",
	"database is not ready":                                       "数据库尚未就绪",
	"deathYear must be between 1 and 9999":                        "逝世年份必须在 1 到 9999 之间",
	"displayName is required":                                     "请填写显示名称",
	"edgeId is required":                                          "缺少关系标识",
	"edgeType must be parent_child or spouse":                     "关系类型必须是 parent_child 或 spouse",
	"expiresInDays must be between 1 and 365":                     "有效期必须在 1 到 365 天之间",
	"family fields are too long":                                  "家族资料内容过长",
	"family name does not match":                                  "家族名称不一致",
	"family name is required":                                     "请填写家族名称",
	"family name or surname is too long":                          "家族名称或姓氏过长",
	"familyId is required":                                        "缺少家族标识",
	"file is required":                                            "请选择要上传的文件",
	"generation must be between 1 and 99":                         "世代必须在 1 到 99 之间",
	"generation name is too long":                                 "字辈名称过长",
	"generation poem is too long":                                 "字辈诗过长",
	"generationNo is duplicated":                                  "世代编号重复",
	"generationNo must be between 1 and 99":                       "世代编号必须在 1 到 99 之间",
	"internal server error":                                       "服务器内部错误，请稍后重试",
	"invalid life status":                                         "生卒状态不正确",
	"invalid login name or password":                              "登录名或密码不正确",
	"invalid login name or recovery code":                         "登录名或找回码不正确",
	"invalid multipart upload":                                    "上传内容格式不正确",
	"invalid request status":                                      "申请状态不正确",
	"invalid session":                                             "登录会话无效，请重新登录",
	"invite code is invalid or expired":                           "邀请码无效或已过期",
	"invite code is too short":                                    "邀请码长度不足",
	"limit must be between 1 and 100":                             "每页数量必须在 1 到 100 之间",
	"login name or phone is already registered":                   "登录名或手机号已被注册",
	"loginName is required":                                       "请填写登录名",
	"merge request is no longer pending":                          "合并申请已被处理",
	"merge request not found":                                     "合并申请不存在",
	"merge request or selected item not found":                    "合并申请或所选内容不存在",
	"merge selection is not valid":                                "合并选择内容不正确",
	"method not allowed":                                          "请求方式不被允许",
	"missing or invalid bearer token":                             "登录凭证缺失或无效",
	"new password must be between 8 and 256 characters":           "新密码长度需为 8 到 256 位",
	"not authenticated":                                           "请先登录",
	"not the active family":                                       "不是当前家族",
	"object storage is not configured":                            "对象存储尚未配置",
	"one or more fields are too long":                             "部分字段内容过长",
	"only an owner or admin can correct relationships":            "只有族长或管理员可以修正亲属关系",
	"only an owner or admin can delete a person":                  "只有族长或管理员可以删除人物",
	"only an owner or admin can edit directly":                    "只有族长或管理员可以直接修改",
	"only an owner or admin can edit generation names":            "只有族长或管理员可以维护字辈",
	"only an owner or admin can review bindings":                  "只有族长或管理员可以审核绑定申请",
	"only an owner or admin can review requests":                  "只有族长或管理员可以审核申请",
	"only an owner or admin can view merge requests":              "只有族长或管理员可以查看合并申请",
	"only an owner or admin can write directly":                   "只有族长或管理员可以直接写入",
	"only JPEG, PNG or WebP images are supported":                 "仅支持 JPEG、PNG 或 WebP 图片",
	"only the family owner can approve a merge":                   "只有族长可以通过合并申请",
	"only the family owner can export data":                       "只有族长可以导出数据",
	"only the family owner can import data":                       "只有族长可以导入数据",
	"only the family owner can reject a merge":                    "只有族长可以拒绝合并申请",
	"only the family owner can transfer ownership":                "只有族长可以转让族长身份",
	"only the owner can archive the family":                       "只有族长可以注销家族",
	"only the owner can create invites":                           "只有族长可以创建邀请",
	"only the owner can export family data":                       "只有族长可以导出家族数据",
	"only the owner can manage branch admins":                     "只有族长可以管理分支管理员",
	"only the owner can view accounts":                            "只有族长可以查看成员账号",
	"only the owner can view invites":                             "只有族长可以查看邀请",
	"operation is not allowed":                                    "不允许执行此操作",
	"parentId and childId are required":                           "请选择父母和子女",
	"parentRole must be father or mother":                         "父母角色必须是父亲或母亲",
	"password is incorrect":                                       "密码不正确",
	"password must be between 8 and 256 characters":               "密码长度需为 8 到 256 位",
	"person not found":                                            "人物不存在",
	"person or branch not found":                                  "人物或家支不存在",
	"personAId and personBId are required":                        "请选择配偶双方",
	"personId is required":                                        "请选择人物",
	"phone is already bound to another account":                   "该手机号已绑定其他账号",
	"phone is not registered":                                     "该手机号尚未注册",
	"phone must use E.164 format":                                 "手机号格式不正确",
	"phone must use E.164 format, e.g. +8613800000000":            "手机号格式不正确，例如 +8613800000000",
	"phone or verification code is invalid":                       "手机号或验证码不正确",
	"photo must be at most 8 MB":                                  "照片不能超过 8 MB",
	"photo storage is not configured":                             "照片存储尚未配置",
	"please accept the user agreement and privacy policy":         "请先同意用户协议和隐私政策",
	"please reload and accept the current terms":                  "请刷新后重新同意最新的用户协议",
	"please wait before requesting another code":                  "请稍后再获取验证码",
	"q must be at most 80 characters":                             "搜索关键词不能超过 80 个字",
	"relationship already exists or role is taken":                "关系已存在，或该亲属角色已被占用",
	"relationship is not valid for this family":                   "该亲属关系不符合当前家族规则",
	"relationship would create a cycle":                           "该亲属关系会造成循环",
	"request is no longer pending":                                "申请已被处理",
	"request is not valid":                                        "申请内容不正确",
	"request not found":                                           "申请不存在",
	"request or target person not found":                          "申请或目标人物不存在",
	"resource is already taken":                                   "该资源已被占用",
	"resource not found":                                          "内容不存在",
	"review note must be at most 2000 characters":                 "审核备注不能超过 2000 个字",
	"rootGeneration must be between 1 and 99":                     "起始世代必须在 1 到 99 之间",
	"rootPersonId is required":                                    "请选择起始人物",
	"select at least one person, story or photo":                  "请至少选择一位人物、一篇故事或一张照片",
	"session is invalid or expired":                               "登录已过期，请重新登录",
	"SMS service is not configured":                               "短信服务尚未配置",
	"startGeneration must be between 1 and 99":                    "起始世代必须在 1 到 99 之间",
	"surname is required":                                         "请填写姓氏",
	"takenAt must be YYYY-MM-DD":                                  "拍摄时间格式必须为 YYYY-MM-DD",
	"targetPersonId is required":                                  "请选择目标人物",
	"the person has changed; refresh and submit again":            "人物资料已更新，请刷新后重新提交",
	"the request does not change any field":                       "申请没有修改任何字段",
	"this account is already a member of that family":             "该账号已经在这个家族中",
	"this branch is outside your admin scope":                     "该家支不在你的管理范围内",
	"this person has changed; reload and try again":               "人物资料已更新，请重新加载后再试",
	"this phone is not registered; register with an invite first": "该手机号尚未注册，请先使用邀请码注册",
	"too many failed attempts; try again later":                   "失败次数过多，请稍后再试",
	"too many generations":                                        "世代数量过多",
	"unsupported request type":                                    "不支持的申请类型",
	"userId and branchId are required":                            "请选择成员和家支",
	"userId is required":                                          "请选择成员",
	"valid login name and an 8+ character password are required":  "请填写正确的登录名和至少 8 位密码",
	"verification code is invalid or expired":                     "验证码无效或已过期",
	"version is required":                                         "缺少资料版本号",
	"you cannot change this person's avatar":                      "你没有权限修改这个人的头像",
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	writeJSONStatus(w, status, "application/json; charset=utf-8", value)
}

func writeJSONStatus(w http.ResponseWriter, status int, contentType string, value any) {
	w.Header().Set("Content-Type", contentType)
	w.WriteHeader(status)
	encoder := json.NewEncoder(w)
	encoder.SetEscapeHTML(false)
	_ = encoder.Encode(value)
}
