-- +goose Up
ALTER TABLE families
    ADD COLUMN generation_poem VARCHAR(2000) NOT NULL DEFAULT '' AFTER description;

-- +goose Down
ALTER TABLE families DROP COLUMN generation_poem;
