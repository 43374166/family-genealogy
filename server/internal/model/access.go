package model

import "time"

type Invite struct {
	ID         string    `json:"id"`
	Code       string    `json:"code"`
	Role       string    `json:"role"`
	BranchID   *string   `json:"branchId,omitempty"`
	BranchName string    `json:"branchName,omitempty"`
	MaxUses    int       `json:"maxUses"`
	UsedCount  int       `json:"usedCount"`
	ExpiresAt  time.Time `json:"expiresAt"`
	Status     string    `json:"status"`
}

type BindingRequest struct {
	ID            string     `json:"id"`
	RequesterName string     `json:"requesterName"`
	PersonID      string     `json:"personId"`
	PersonName    string     `json:"personName"`
	Status        string     `json:"status"`
	ReviewerName  string     `json:"reviewerName,omitempty"`
	ReviewNote    string     `json:"reviewNote,omitempty"`
	SubmittedAt   time.Time  `json:"submittedAt"`
	ReviewedAt    *time.Time `json:"reviewedAt,omitempty"`
}

type BindingRequestPage struct {
	Items []BindingRequest `json:"items"`
}
