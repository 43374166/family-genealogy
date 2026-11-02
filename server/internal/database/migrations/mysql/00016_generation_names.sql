-- +goose Up
CREATE TABLE family_generation_names (
    id            CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    family_id     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    generation_no SMALLINT UNSIGNED NOT NULL,
    name          VARCHAR(20) NOT NULL,
    created_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
                  ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uq_generation_names_family_generation (family_id, generation_no),
    CONSTRAINT fk_generation_names_family
        FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE CASCADE,
    CONSTRAINT chk_generation_names_no CHECK (generation_no BETWEEN 1 AND 99),
    CONSTRAINT chk_generation_names_name CHECK (CHAR_LENGTH(name) BETWEEN 1 AND 20)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- +goose Down
DROP TABLE IF EXISTS family_generation_names;
