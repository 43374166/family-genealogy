-- +goose Up
-- Stories can carry up to nine images. Images reuse family_photos so the
-- existing private object storage, ownership checks and content endpoint stay
-- in one place; this table only records the ordered attachment.
ALTER TABLE family_stories
    ADD UNIQUE KEY uk_family_stories_id_family (id, family_id);

CREATE TABLE family_story_photos (
    story_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    photo_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    family_id  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (story_id, photo_id),
    KEY ix_family_story_photos_order (story_id, sort_order),
    KEY ix_family_story_photos_photo (photo_id, family_id),
    CONSTRAINT fk_family_story_photos_story FOREIGN KEY (story_id, family_id)
        REFERENCES family_stories (id, family_id) ON DELETE CASCADE,
    CONSTRAINT fk_family_story_photos_photo FOREIGN KEY (photo_id, family_id)
        REFERENCES family_photos (id, family_id) ON DELETE CASCADE,
    CONSTRAINT chk_family_story_photos_order CHECK (sort_order BETWEEN 0 AND 8)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='家族故事附图，最多九张';

-- +goose Down
DROP TABLE IF EXISTS family_story_photos;

ALTER TABLE family_stories
    DROP KEY uk_family_stories_id_family;
