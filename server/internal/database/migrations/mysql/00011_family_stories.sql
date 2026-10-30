-- +goose Up
CREATE TABLE family_stories (
    id              CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    family_id       CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    author_user_id  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    person_id       CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    title           VARCHAR(120) NOT NULL,
    body            MEDIUMTEXT NOT NULL,
    status          VARCHAR(16) NOT NULL DEFAULT 'active',
    created_at      DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at      DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY ix_family_stories_family_time (family_id, status, created_at DESC),
    KEY ix_family_stories_person (family_id, person_id),
    CONSTRAINT fk_family_stories_family FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_family_stories_author FOREIGN KEY (author_user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT fk_family_stories_person FOREIGN KEY (person_id, family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT chk_family_stories_status CHECK (status IN ('active', 'deleted')),
    CONSTRAINT chk_family_stories_title CHECK (CHAR_LENGTH(TRIM(title)) BETWEEN 1 AND 120)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='家族故事/族人事迹';

-- +goose Down
DROP TABLE IF EXISTS family_stories;
