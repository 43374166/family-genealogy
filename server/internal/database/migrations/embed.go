package migrations

import "embed"

// FS contains ordered SQL migrations. Goose reads this filesystem so a single
// binary can migrate without relying on the caller's working directory.
//
//go:embed *.sql
var FS embed.FS
