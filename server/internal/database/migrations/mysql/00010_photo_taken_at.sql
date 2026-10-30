-- +goose Up
ALTER TABLE family_photos
    ADD COLUMN taken_at DATETIME(6) NULL AFTER caption,
    ADD INDEX ix_family_photos_taken (family_id, taken_at);

-- +goose Down
ALTER TABLE family_photos
    DROP INDEX ix_family_photos_taken,
    DROP COLUMN taken_at;
