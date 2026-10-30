package httpapi

import (
	"encoding/json"
	"net/http"
	"strings"

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
		Title:     http.StatusText(status),
		Status:    status,
		Detail:    detail,
		Instance:  r.URL.Path,
		Code:      code,
		RequestID: chimw.GetReqID(r.Context()),
	}
	writeJSONStatus(w, status, problemContentType, p)
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
