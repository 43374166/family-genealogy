-- +goose Up
CREATE TABLE notifications (
    id            BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id       CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    family_id     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    kind          VARCHAR(40) NOT NULL,
    title         VARCHAR(160) NOT NULL,
    body          VARCHAR(1000) NOT NULL DEFAULT '',
    target_type   VARCHAR(40) NOT NULL DEFAULT '',
    target_id     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    is_read       TINYINT(1) NOT NULL DEFAULT 0,
    created_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY ix_notifications_user_time (user_id, family_id, created_at DESC),
    KEY ix_notifications_unread (user_id, family_id, is_read, created_at DESC),
    CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT fk_notifications_family FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT chk_notifications_title CHECK (CHAR_LENGTH(TRIM(title)) BETWEEN 1 AND 160)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='站内通知；按用户和家族隔离';

-- +goose Down
DROP TABLE IF EXISTS notifications;
