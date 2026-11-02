-- +goose Up
CREATE TABLE family_merge_requests (
    id                  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    source_family_id    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    target_family_id    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    requester_user_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    status              VARCHAR(16) NOT NULL DEFAULT 'pending',
    reviewer_user_id    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    review_note         VARCHAR(2000) NOT NULL DEFAULT '',
    selected_person_ids JSON NULL,
    selected_story_ids  JSON NULL,
    selected_photo_ids  JSON NULL,
    target_branch_id    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    start_generation    SMALLINT NULL,
    attach_parent_id    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    reviewed_at         DATETIME(6) NULL,
    created_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY ix_family_merge_target_status (target_family_id, status, created_at DESC),
    KEY ix_family_merge_source (source_family_id, status),
    CONSTRAINT fk_family_merge_source FOREIGN KEY (source_family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_family_merge_target FOREIGN KEY (target_family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_family_merge_requester FOREIGN KEY (requester_user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT fk_family_merge_reviewer FOREIGN KEY (reviewer_user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT fk_family_merge_branch FOREIGN KEY (target_branch_id, target_family_id)
        REFERENCES branches (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT fk_family_merge_parent FOREIGN KEY (attach_parent_id, target_family_id)
        REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT chk_family_merge_status CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    CONSTRAINT chk_family_merge_distinct CHECK (source_family_id <> target_family_id),
    CONSTRAINT chk_family_merge_start_generation CHECK (start_generation IS NULL OR start_generation BETWEEN 1 AND 99),
    CONSTRAINT chk_family_merge_review_state CHECK (
        (status = 'pending' AND reviewer_user_id IS NULL AND reviewed_at IS NULL)
        OR (status = 'approved' AND reviewer_user_id IS NOT NULL AND reviewed_at IS NOT NULL)
        OR (status = 'rejected' AND reviewer_user_id IS NOT NULL AND reviewed_at IS NOT NULL)
        OR status = 'cancelled'
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='家族合并申请：旧家族数据并入新家族，由目标家族族长审核';

-- +goose Down
DROP TABLE IF EXISTS family_merge_requests;
