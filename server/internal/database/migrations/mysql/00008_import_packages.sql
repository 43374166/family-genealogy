-- +goose Up
CREATE TABLE family_import_packages (
    id                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    source_family_id      CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    created_by_user_id    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    root_person_id        CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    code                  VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    payload               JSON NOT NULL,
    person_count          INT UNSIGNED NOT NULL,
    relationship_count    INT UNSIGNED NOT NULL,
    status                VARCHAR(16) NOT NULL DEFAULT 'active',
    expires_at            DATETIME(6) NOT NULL,
    used_by_family_id     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    used_by_user_id       CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    used_at               DATETIME(6) NULL,
    created_at            DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_import_packages_code (code),
    KEY ix_import_packages_source (source_family_id, status, created_at DESC),
    CONSTRAINT fk_import_packages_family FOREIGN KEY (source_family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_import_packages_creator FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT fk_import_packages_root FOREIGN KEY (root_person_id, source_family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT fk_import_packages_used_family FOREIGN KEY (used_by_family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_import_packages_used_user FOREIGN KEY (used_by_user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT chk_import_packages_status CHECK (status IN ('active', 'used', 'revoked')),
    CONSTRAINT chk_import_packages_code CHECK (CHAR_LENGTH(code) BETWEEN 6 AND 16),
    CONSTRAINT chk_import_packages_counts CHECK (person_count > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='旁支数据导入包；一次性代码，目标族长消费';

CREATE TABLE family_imports (
    id                  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    package_id          CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    source_family_id    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    target_family_id    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    imported_by_user_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    target_branch_id    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    target_parent_id    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    root_generation     SMALLINT NOT NULL,
    person_count        INT UNSIGNED NOT NULL,
    mapping             JSON NOT NULL,
    created_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY ix_family_imports_target (target_family_id, created_at DESC),
    CONSTRAINT fk_family_imports_package FOREIGN KEY (package_id) REFERENCES family_import_packages (id) ON DELETE RESTRICT,
    CONSTRAINT fk_family_imports_source FOREIGN KEY (source_family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_family_imports_target FOREIGN KEY (target_family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_family_imports_actor FOREIGN KEY (imported_by_user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT fk_family_imports_branch FOREIGN KEY (target_branch_id, target_family_id) REFERENCES branches (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT fk_family_imports_parent FOREIGN KEY (target_parent_id, target_family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT chk_family_imports_generation CHECK (root_generation BETWEEN 1 AND 99),
    CONSTRAINT chk_family_imports_count CHECK (person_count > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='导入操作审计记录';

-- +goose Down
DROP TABLE IF EXISTS family_imports;
DROP TABLE IF EXISTS family_import_packages;
