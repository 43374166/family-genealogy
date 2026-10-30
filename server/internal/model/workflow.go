package model

import "time"

// PersonEditChanges contains only the fields the client wants to change.
// A pointer distinguishes "leave unchanged" (nil) from "clear this field"
// (pointer to an empty string).
type PersonEditChanges struct {
	BirthPlace *string `json:"birthPlace,omitempty"`
	Residence  *string `json:"residence,omitempty"`
	Occupation *string `json:"occupation,omitempty"`
	Education  *string `json:"education,omitempty"`
	Biography  *string `json:"biography,omitempty"`
}

func (c PersonEditChanges) FieldKeys() []string {
	fields := make([]string, 0, 5)
	if c.BirthPlace != nil {
		fields = append(fields, "birthPlace")
	}
	if c.Residence != nil {
		fields = append(fields, "residence")
	}
	if c.Occupation != nil {
		fields = append(fields, "occupation")
	}
	if c.Education != nil {
		fields = append(fields, "education")
	}
	if c.Biography != nil {
		fields = append(fields, "biography")
	}
	return fields
}

func (c PersonEditChanges) Empty() bool {
	return len(c.FieldKeys()) == 0
}

type EditRequest struct {
	ID              string            `json:"id"`
	FamilyID        string            `json:"familyId"`
	RequesterUserID string            `json:"requesterUserId"`
	RequesterName   string            `json:"requesterName"`
	RequestType     string            `json:"requestType"`
	TargetPersonID  *string           `json:"targetPersonId,omitempty"`
	TargetName      string            `json:"targetName"`
	BaseVersion     *int              `json:"baseVersion,omitempty"`
	Changes         PersonEditChanges `json:"changes"`
	ChangedFields   []string          `json:"changedFields"`
	Payload         map[string]any    `json:"payload,omitempty"`
	Summary         string            `json:"summary,omitempty"`
	Status          string            `json:"status"`
	ReviewerUserID  *string           `json:"reviewerUserId,omitempty"`
	ReviewerName    string            `json:"reviewerName,omitempty"`
	ReviewNote      string            `json:"reviewNote,omitempty"`
	SubmittedAt     time.Time         `json:"submittedAt"`
	ReviewedAt      *time.Time        `json:"reviewedAt,omitempty"`
}

type EditRequestPage struct {
	Items []EditRequest `json:"items"`
}
