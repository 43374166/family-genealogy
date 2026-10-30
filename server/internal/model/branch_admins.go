package model

import "time"

type FamilyAccount struct {
	UserID      string `json:"userId"`
	LoginName   string `json:"loginName"`
	DisplayName string `json:"displayName"`
	Role        string `json:"role"`
	PersonName  string `json:"personName,omitempty"`
}

type BranchAdminGrant struct {
	ID                 string    `json:"id"`
	UserID             string    `json:"userId"`
	DisplayName        string    `json:"displayName"`
	LoginName          string    `json:"loginName"`
	BranchID           string    `json:"branchId"`
	BranchName         string    `json:"branchName"`
	IncludeDescendants bool      `json:"includeDescendants"`
	Status             string    `json:"status"`
	CreatedAt          time.Time `json:"createdAt"`
}
