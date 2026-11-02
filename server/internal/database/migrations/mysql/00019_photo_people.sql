-- +goose Up
-- A family photo can be tagged with more than one person. The legacy
-- family_photos.person_id column stays as the primary subject for older
-- clients; this join table is the authoritative multi-person tag list.
ALTER TABLE family_photos
    ADD UNIQUE KEY uk_family_photos_id_family (id, family_id);

CREATE TABLE family_photo_people (
    photo_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    person_id  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    family_id  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (photo_id, person_id),
    KEY ix_family_photo_people_person (family_id, person_id),
    CONSTRAINT fk_family_photo_people_photo FOREIGN KEY (photo_id, family_id)
        REFERENCES family_photos (id, family_id) ON DELETE CASCADE,
    CONSTRAINT fk_family_photo_people_person FOREIGN KEY (person_id, family_id)
        REFERENCES persons (id, family_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='家族照片与人物多对多标签';

INSERT INTO family_photo_people (photo_id, person_id, family_id)
SELECT id, person_id, family_id
FROM family_photos
WHERE person_id IS NOT NULL;

-- +goose Down
DROP TABLE IF EXISTS family_photo_people;

ALTER TABLE family_photos
    DROP KEY uk_family_photos_id_family;
