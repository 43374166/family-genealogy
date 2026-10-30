-- +goose Up
ALTER TABLE users
    ADD COLUMN recovery_code_hash VARCHAR(255) NULL AFTER password_hash,
    ADD COLUMN recovery_code_created_at DATETIME(6) NULL AFTER recovery_code_hash;

-- +goose Down
ALTER TABLE users
    DROP COLUMN recovery_code_created_at,
    DROP COLUMN recovery_code_hash;
