-- +goose Up
ALTER TABLE users
    ADD COLUMN phone_verified_at DATETIME(6) NULL AFTER phone;

-- +goose Down
ALTER TABLE users
    DROP COLUMN phone_verified_at;
