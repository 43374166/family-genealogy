-- +goose Up
ALTER TABLE persons
    ADD COLUMN avatar_object_key VARCHAR(512) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER biography,
    ADD COLUMN avatar_content_type VARCHAR(80) NOT NULL DEFAULT '' AFTER avatar_object_key;

-- +goose Down
ALTER TABLE persons
    DROP COLUMN avatar_content_type,
    DROP COLUMN avatar_object_key;
