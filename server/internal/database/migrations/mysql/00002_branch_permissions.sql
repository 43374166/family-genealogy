-- +goose Up
ALTER TABLE branches
    ADD COLUMN parent_branch_id CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL AFTER family_id,
    ADD KEY ix_branches_family_parent (family_id, parent_branch_id),
    ADD CONSTRAINT fk_branches_parent
        FOREIGN KEY (parent_branch_id, family_id)
        REFERENCES branches (id, family_id)
        ON DELETE RESTRICT;

CREATE TABLE branch_admin_grants (
    id                   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    family_id            CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    branch_id            CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id              CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    include_descendants  TINYINT(1) NOT NULL DEFAULT 1,
    status               VARCHAR(16) NOT NULL DEFAULT 'active',
    granted_by_user_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    created_at           DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_branch_admin_grant (family_id, branch_id, user_id),
    KEY ix_branch_admin_user (family_id, user_id, status),
    KEY ix_branch_admin_branch (family_id, branch_id, status),
    CONSTRAINT fk_branch_admin_family
        FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_branch_admin_branch
        FOREIGN KEY (branch_id, family_id) REFERENCES branches (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT fk_branch_admin_user
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT fk_branch_admin_grantor
        FOREIGN KEY (granted_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT chk_branch_admin_status CHECK (status IN ('active', 'revoked'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='分支管理员授权；owner 全局，admin 按分支/子树授权';

-- +goose Down
DROP TABLE IF EXISTS branch_admin_grants;
ALTER TABLE branches
    DROP FOREIGN KEY fk_branches_parent,
    DROP KEY ix_branches_family_parent,
    DROP COLUMN parent_branch_id;
