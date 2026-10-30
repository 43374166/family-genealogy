-- +goose Up
ALTER TABLE user_sessions
    ADD COLUMN active_family_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER user_id,
    ADD KEY ix_user_sessions_active_family (active_family_id),
    ADD CONSTRAINT fk_user_sessions_active_family
        FOREIGN KEY (active_family_id) REFERENCES families (id) ON DELETE SET NULL;

-- +goose Down
ALTER TABLE user_sessions
    DROP FOREIGN KEY fk_user_sessions_active_family,
    DROP KEY ix_user_sessions_active_family,
    DROP COLUMN active_family_id;
