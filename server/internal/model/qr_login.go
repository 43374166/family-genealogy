package model

import "time"

const (
	QRStatusPending   = "pending"
	QRStatusScanned   = "scanned"
	QRStatusConfirmed = "confirmed"
	QRStatusConsumed  = "consumed"
	QRStatusExpired   = "expired"
	QRStatusCancelled = "cancelled"
)

// QRLoginSession is the server-side state of one web sign-in attempt.
// Secret hashes and raw user agents never leave the server.
type QRLoginSession struct {
	ID                 string
	Status             string
	RequesterIP        string
	RequesterCity      string
	RequesterRegion    string
	RequesterCountry   string
	RequesterUserAgent string
	RequesterDevice    string
	ScannedUserID      *string
	UserID             *string
	FamilyID           *string
	CreatedAt          time.Time
	ExpiresAt          time.Time
	ScannedAt          *time.Time
	ConfirmedAt        *time.Time
	ConsumedAt         *time.Time
}
