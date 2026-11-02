package model

import "time"

// FamilyMergeRequest records a request to bring data from the family a user
// left behind into the family they just joined. The target family owner picks
// the individual items and where they land.
type FamilyMergeRequest struct {
	ID                string     `json:"id"`
	SourceFamilyID    string     `json:"sourceFamilyId"`
	SourceFamilyName  string     `json:"sourceFamilyName"`
	TargetFamilyID    string     `json:"targetFamilyId"`
	TargetFamilyName  string     `json:"targetFamilyName"`
	RequesterUserID   string     `json:"requesterUserId"`
	RequesterName     string     `json:"requesterName"`
	Status            string     `json:"status"`
	ReviewerUserID    *string    `json:"reviewerUserId,omitempty"`
	ReviewerName      string     `json:"reviewerName,omitempty"`
	ReviewNote        string     `json:"reviewNote,omitempty"`
	PersonCount       int        `json:"personCount"`
	StoryCount        int        `json:"storyCount"`
	PhotoCount        int        `json:"photoCount"`
	TargetBranchID    *string    `json:"targetBranchId,omitempty"`
	StartGeneration   *int       `json:"startGeneration,omitempty"`
	AttachParentID    *string    `json:"attachParentId,omitempty"`
	SelectedPersonIDs []string   `json:"selectedPersonIds,omitempty"`
	SelectedStoryIDs  []string   `json:"selectedStoryIds,omitempty"`
	SelectedPhotoIDs  []string   `json:"selectedPhotoIds,omitempty"`
	CreatedAt         time.Time  `json:"createdAt"`
	ReviewedAt        *time.Time `json:"reviewedAt,omitempty"`
}

type MergePersonItem struct {
	ID             string  `json:"id"`
	FullName       string  `json:"fullName"`
	GenerationNo   int     `json:"generationNo"`
	GenerationName string  `json:"generationName,omitempty"`
	Gender         string  `json:"gender"`
	LifeStatus     string  `json:"lifeStatus"`
	BranchID       *string `json:"branchId,omitempty"`
	BranchName     string  `json:"branchName,omitempty"`
	BirthYear      *int    `json:"birthYear,omitempty"`
}

type MergeStoryItem struct {
	ID         string    `json:"id"`
	Title      string    `json:"title"`
	PersonName string    `json:"personName,omitempty"`
	PhotoCount int       `json:"photoCount"`
	CreatedAt  time.Time `json:"createdAt"`
}

type MergePhotoItem struct {
	ID          string    `json:"id"`
	Caption     string    `json:"caption"`
	PersonNames []string  `json:"personNames,omitempty"`
	CreatedAt   time.Time `json:"createdAt"`
}

type FamilyMergeDetail struct {
	Request       FamilyMergeRequest `json:"request"`
	Persons       []MergePersonItem  `json:"persons"`
	Stories       []MergeStoryItem   `json:"stories"`
	Photos        []MergePhotoItem   `json:"photos"`
	Branches      []Branch           `json:"branches"`
	MinGeneration int                `json:"minGeneration"`
	MaxGeneration int                `json:"maxGeneration"`
}

type FamilyMergeResult struct {
	Request         FamilyMergeRequest `json:"request"`
	ImportedPersons int                `json:"importedPersons"`
	ImportedStories int                `json:"importedStories"`
	ImportedPhotos  int                `json:"importedPhotos"`
	SourceArchived  bool               `json:"sourceArchived"`
}

type JoinFamilyResult struct {
	User             User                 `json:"user"`
	Membership       Membership           `json:"membership"`
	Family           Family               `json:"family"`
	Families         []FamilyMembership   `json:"families"`
	ArchivedFamilies []Family             `json:"archivedFamilies,omitempty"`
	MergeRequests    []FamilyMergeRequest `json:"mergeRequests,omitempty"`
}
