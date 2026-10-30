-- +goose Up
ALTER TABLE users
    ADD COLUMN terms_accepted_at DATETIME(6) NULL AFTER last_login_at,
    ADD COLUMN terms_version VARCHAR(20) NOT NULL DEFAULT '' AFTER terms_accepted_at;

-- +goose Down
ALTER TABLE users
    DROP COLUMN terms_version,
    DROP COLUMN terms_accepted_at;
