-- +goose Up
CREATE TABLE family_photos (
    id                   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    family_id            CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    person_id            CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    uploaded_by_user_id  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    object_key           VARCHAR(512) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    content_type         VARCHAR(80) NOT NULL,
    size_bytes           BIGINT UNSIGNED NOT NULL,
    caption              VARCHAR(500) NOT NULL DEFAULT '',
    status               VARCHAR(16) NOT NULL DEFAULT 'active',
    created_at           DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_family_photos_object (object_key),
    KEY ix_family_photos_family_time (family_id, status, created_at DESC),
    KEY ix_family_photos_person (family_id, person_id, status),
    CONSTRAINT fk_family_photos_family FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_family_photos_person FOREIGN KEY (person_id, family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT fk_family_photos_uploader FOREIGN KEY (uploaded_by_user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT chk_family_photos_status CHECK (status IN ('active', 'deleted')),
    CONSTRAINT chk_family_photos_size CHECK (size_bytes > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='家族相册照片元数据；对象存于私有 OBS';

-- +goose Down
DROP TABLE IF EXISTS family_photos;
