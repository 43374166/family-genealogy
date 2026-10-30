package model

import "time"

type ImportPackage struct {
	Code              string    `json:"code"`
	SourceFamilyName  string    `json:"sourceFamilyName"`
	RootName          string    `json:"rootName"`
	PersonCount       int       `json:"personCount"`
	RelationshipCount int       `json:"relationshipCount"`
	ExpiresAt         time.Time `json:"expiresAt"`
}

type ImportPersonPreview struct {
	FullName   string `json:"fullName"`
	Generation int    `json:"generationNo"`
	Relation   string `json:"relation,omitempty"`
}

type ImportPreview struct {
	Code              string                `json:"code"`
	SourceFamilyName  string                `json:"sourceFamilyName"`
	RootName          string                `json:"rootName"`
	PersonCount       int                   `json:"personCount"`
	RelationshipCount int                   `json:"relationshipCount"`
	ExpiresAt         time.Time             `json:"expiresAt"`
	Persons           []ImportPersonPreview `json:"persons"`
}

type ImportResult struct {
	SourceFamilyName string `json:"sourceFamilyName"`
	PersonCount      int    `json:"personCount"`
	RootName         string `json:"rootName"`
	RootGeneration   int    `json:"rootGeneration"`
}
