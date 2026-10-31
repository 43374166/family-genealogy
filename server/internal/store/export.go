package store

import (
	"context"
	"fmt"
	"time"

	"github.com/43374166/family-genealogy/server/internal/model"
)

func (s *Store) ExportFamily(ctx context.Context, familyID string) (*model.FamilyExport, error) {
	tree, err := s.GetTree(ctx, familyID, 0, "")
	if err != nil {
		return nil, err
	}
	family, err := s.GetFamily(ctx, familyID)
	if err != nil {
		return nil, err
	}
	branches, err := s.ListBranches(ctx, familyID)
	if err != nil {
		return nil, err
	}
	persons := make([]model.Person, 0, len(tree.Persons))
	for _, summary := range tree.Persons {
		person, err := s.GetPerson(ctx, familyID, summary.ID)
		if err != nil {
			return nil, fmt.Errorf("export person %s: %w", summary.ID, err)
		}
		persons = append(persons, *person)
	}
	stories, err := s.ListStories(ctx, familyID, 100)
	if err != nil {
		return nil, err
	}
	photos, err := s.ListPhotos(ctx, familyID, PhotoFilter{Limit: 100})
	if err != nil {
		return nil, err
	}
	return &model.FamilyExport{
		Version: 1, ExportedAt: time.Now().UTC(),
		Family: *family, Branches: branches, Persons: persons,
		ParentChild: tree.ParentChild, Spouses: tree.Spouses,
		Stories: stories, Photos: photos,
	}, nil
}
