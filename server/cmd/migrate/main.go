package main

import (
	"context"
	"fmt"
	"log/slog"
	"os"
	"strings"

	"github.com/43374166/family-genealogy/server/internal/database"
)

func main() {
	command := "up"
	if len(os.Args) > 1 {
		command = strings.TrimSpace(os.Args[1])
	}

	dsn := strings.TrimSpace(os.Getenv("DATABASE_URL"))
	if dsn == "" {
		slog.Error("DATABASE_URL is required")
		os.Exit(1)
	}

	ctx := context.Background()
	if err := database.Migrate(ctx, dsn, command); err != nil {
		slog.Error("migration failed", "command", command, "error", err)
		os.Exit(1)
	}
	fmt.Printf("migrations %s completed\n", command)
}
