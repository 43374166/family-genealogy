-- +goose Up
CREATE TABLE family_invites (
    id                  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    family_id           CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    code                VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    role                VARCHAR(16) NOT NULL DEFAULT 'member',
    branch_id           CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    max_uses            INT UNSIGNED NOT NULL DEFAULT 1,
    used_count          INT UNSIGNED NOT NULL DEFAULT 0,
    expires_at          DATETIME(6) NOT NULL,
    created_by_user_id  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    status              VARCHAR(16) NOT NULL DEFAULT 'active',
    created_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_family_invites_code (code),
    KEY ix_family_invites_family_status (family_id, status, expires_at),
    CONSTRAINT fk_invites_family FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_invites_branch FOREIGN KEY (branch_id, family_id) REFERENCES branches (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT fk_invites_creator FOREIGN KEY (created_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT chk_invites_role CHECK (role IN ('member', 'admin')),
    CONSTRAINT chk_invites_status CHECK (status IN ('active', 'revoked')),
    CONSTRAINT chk_invites_uses CHECK (max_uses > 0 AND used_count <= max_uses),
    CONSTRAINT chk_invites_code CHECK (CHAR_LENGTH(code) BETWEEN 6 AND 16)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='家庭邀请码；可限定分支与角色';

CREATE TABLE person_binding_requests (
    id                  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    family_id           CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    requester_user_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    person_id           CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    status              VARCHAR(16) NOT NULL DEFAULT 'pending',
    reviewer_user_id    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    review_note         VARCHAR(2000) NOT NULL DEFAULT '',
    submitted_at        DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    reviewed_at         DATETIME(6) NULL,
    pending_user_key    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
                            GENERATED ALWAYS AS (
                                CASE WHEN status = 'pending' THEN requester_user_id ELSE NULL END
                            ) STORED,
    pending_person_key  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
                            GENERATED ALWAYS AS (
                                CASE WHEN status = 'pending' THEN person_id ELSE NULL END
                            ) STORED,
    PRIMARY KEY (id),
    UNIQUE KEY uk_binding_pending_user (pending_user_key),
    UNIQUE KEY uk_binding_pending_person (pending_person_key),
    KEY ix_binding_family_status (family_id, status, submitted_at DESC),
    CONSTRAINT fk_binding_family FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_binding_requester FOREIGN KEY (requester_user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT fk_binding_person FOREIGN KEY (person_id, family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT fk_binding_reviewer FOREIGN KEY (reviewer_user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT chk_binding_status CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    CONSTRAINT chk_binding_review_state CHECK (
        (status = 'pending' AND reviewer_user_id IS NULL AND reviewed_at IS NULL)
        OR (status IN ('approved', 'rejected') AND reviewer_user_id IS NOT NULL AND reviewed_at IS NOT NULL)
        OR status = 'cancelled'
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='账号与族谱人物绑定申请；通过后写入 membership.person_id';

-- +goose Down
DROP TABLE IF EXISTS person_binding_requests;
DROP TABLE IF EXISTS family_invites;
