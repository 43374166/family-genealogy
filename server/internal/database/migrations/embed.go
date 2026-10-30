package migrations

import "embed"

// FS embeds both the active MySQL migrations and the preserved PostgreSQL 17
// design reference. Runtime migration selection is restricted to mysql/.
//
//go:embed mysql/*.sql postgres/*.sql
var FS embed.FS
