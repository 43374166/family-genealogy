package model

import (
	"fmt"
	"strings"
	"time"
)

type User struct {
	ID            string `json:"id"`
	DisplayName   string `json:"displayName"`
	LoginName     string `json:"loginName"`
	Phone         string `json:"phone,omitempty"`
	Status        string `json:"status"`
	TermsAccepted bool   `json:"termsAccepted"`
}

type Family struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Surname     string `json:"surname"`
	Motto       string `json:"motto"`
	Region      string `json:"region"`
	Description string `json:"description"`
	Status      string `json:"status"`
	MemberCount int    `json:"memberCount"`
	BranchCount int    `json:"branchCount"`
	Version     int    `json:"version"`
}

type Membership struct {
	ID       string    `json:"id"`
	Role     string    `json:"role"`
	Status   string    `json:"status"`
	PersonID *string   `json:"personId,omitempty"`
	JoinedAt time.Time `json:"joinedAt"`
}

type PartialDate struct {
	Year        *int   `json:"year,omitempty"`
	Month       *int   `json:"month,omitempty"`
	Day         *int   `json:"day,omitempty"`
	Calendar    string `json:"calendar,omitempty"`
	IsLeapMonth bool   `json:"isLeapMonth,omitempty"`
	Text        string `json:"text,omitempty"`
}

type Branch struct {
	ID        string  `json:"id"`
	ParentID  *string `json:"parentId,omitempty"`
	Name      string  `json:"name"`
	SortOrder int     `json:"sortOrder"`
}

type PersonSummary struct {
	ID              string       `json:"id"`
	FullName        string       `json:"fullName"`
	Surname         string       `json:"surname"`
	GivenName       string       `json:"givenName"`
	CourtesyName    string       `json:"courtesyName,omitempty"`
	Alias           string       `json:"alias,omitempty"`
	Gender          string       `json:"gender"`
	GenerationNo    int          `json:"generationNo"`
	GenerationLabel string       `json:"generationLabel"`
	BirthOrder      *int         `json:"birthOrder,omitempty"`
	BranchID        *string      `json:"branchId,omitempty"`
	Birth           *PartialDate `json:"birth,omitempty"`
	Death           *PartialDate `json:"death,omitempty"`
	LifeStatus      string       `json:"lifeStatus"`
	Status          string       `json:"status"`
	Version         int          `json:"version"`
	HasAvatar       bool         `json:"hasAvatar"`
}

type Person struct {
	PersonSummary
	BirthPlace string     `json:"birthPlace,omitempty"`
	Residence  string     `json:"residence,omitempty"`
	Occupation string     `json:"occupation,omitempty"`
	Education  string     `json:"education,omitempty"`
	Biography  string     `json:"biography,omitempty"`
	Parents    []Relative `json:"parents,omitempty"`
	Children   []Relative `json:"children,omitempty"`
	Spouses    []Relative `json:"spouses,omitempty"`
	CreatedAt  time.Time  `json:"createdAt"`
	UpdatedAt  time.Time  `json:"updatedAt"`
}

type Relative struct {
	EdgeID   string `json:"edgeId"`
	PersonID string `json:"personId"`
	FullName string `json:"fullName"`
	Relation string `json:"relation"`
}

type ParentChildEdge struct {
	ID         string `json:"id"`
	ParentID   string `json:"parentId"`
	ChildID    string `json:"childId"`
	ParentRole string `json:"parentRole"`
	Status     string `json:"status"`
}

type SpouseEdge struct {
	ID        string `json:"id"`
	PersonAID string `json:"personAId"`
	PersonBID string `json:"personBId"`
	Status    string `json:"status"`
	StartYear *int   `json:"startYear,omitempty"`
	EndYear   *int   `json:"endYear,omitempty"`
}

type Photo struct {
	ID               string     `json:"id"`
	FamilyID         string     `json:"familyId"`
	PersonID         *string    `json:"personId,omitempty"`
	PersonName       string     `json:"personName,omitempty"`
	UploadedByUserID string     `json:"uploadedByUserId"`
	UploadedByName   string     `json:"uploadedByName"`
	ContentType      string     `json:"contentType"`
	SizeBytes        int64      `json:"sizeBytes"`
	Caption          string     `json:"caption"`
	TakenAt          *time.Time `json:"takenAt,omitempty"`
	CreatedAt        time.Time  `json:"createdAt"`
}

type Notification struct {
	ID         int64     `json:"id"`
	Kind       string    `json:"kind"`
	Title      string    `json:"title"`
	Body       string    `json:"body"`
	TargetType string    `json:"targetType"`
	TargetID   *string   `json:"targetId,omitempty"`
	IsRead     bool      `json:"isRead"`
	CreatedAt  time.Time `json:"createdAt"`
}

type Story struct {
	ID           string    `json:"id"`
	FamilyID     string    `json:"familyId"`
	AuthorUserID string    `json:"authorUserId"`
	AuthorName   string    `json:"authorName"`
	PersonID     *string   `json:"personId,omitempty"`
	PersonName   string    `json:"personName,omitempty"`
	Title        string    `json:"title"`
	Body         string    `json:"body"`
	CreatedAt    time.Time `json:"createdAt"`
	UpdatedAt    time.Time `json:"updatedAt"`
}

type FamilyExport struct {
	Version     int               `json:"version"`
	ExportedAt  time.Time         `json:"exportedAt"`
	Family      Family            `json:"family"`
	Branches    []Branch          `json:"branches"`
	Persons     []Person          `json:"persons"`
	ParentChild []ParentChildEdge `json:"parentChild"`
	Spouses     []SpouseEdge      `json:"spouses"`
	Stories     []Story           `json:"stories"`
	Photos      []Photo           `json:"photos"`
}

type Activity struct {
	ID          int64     `json:"id"`
	Action      string    `json:"action"`
	ActorName   string    `json:"actorName"`
	Summary     string    `json:"summary"`
	Detail      string    `json:"detail"`
	Kind        string    `json:"kind"`
	NeedsReview bool      `json:"needsReview"`
	CreatedAt   time.Time `json:"createdAt"`
}

type Tree struct {
	FamilyID    string            `json:"familyId"`
	Version     int               `json:"version"`
	Persons     []PersonSummary   `json:"persons"`
	ParentChild []ParentChildEdge `json:"parentChild"`
	Spouses     []SpouseEdge      `json:"spouses"`
}

type Session struct {
	Token     string    `json:"token"`
	ExpiresAt time.Time `json:"expiresAt"`
	User      User      `json:"user"`
	Family    Family    `json:"family"`
}

type FamilyMembership struct {
	Family     Family     `json:"family"`
	Membership Membership `json:"membership"`
}

type Me struct {
	User       User               `json:"user"`
	Membership Membership         `json:"membership"`
	Family     Family             `json:"family"`
	Families   []FamilyMembership `json:"families"`
}

func GenerationLabel(generation int) string {
	if generation <= 0 {
		return ""
	}
	return "第" + chineseNumber(generation) + "世"
}

func chineseNumber(n int) string {
	digits := []string{"零", "一", "二", "三", "四", "五", "六", "七", "八", "九"}
	if n < 10 {
		return digits[n]
	}
	if n < 20 {
		if n == 10 {
			return "十"
		}
		return "十" + digits[n%10]
	}
	if n < 100 {
		if n%10 == 0 {
			return digits[n/10] + "十"
		}
		return digits[n/10] + "十" + digits[n%10]
	}
	return fmt.Sprintf("%d", n)
}

func RoleLabel(role string) string {
	switch strings.ToLower(role) {
	case "father":
		return "父亲"
	case "mother":
		return "母亲"
	case "parent":
		return "父母"
	case "adoptive":
		return "养父母"
	case "step":
		return "继父母"
	case "guardian":
		return "监护人"
	default:
		return "亲属"
	}
}
