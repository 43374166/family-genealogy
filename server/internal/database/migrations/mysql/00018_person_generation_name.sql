-- +goose Up
ALTER TABLE persons
    ADD COLUMN generation_name VARCHAR(20) NOT NULL DEFAULT '' AFTER generation_no;

-- +goose Down
ALTER TABLE persons DROP COLUMN generation_name;
