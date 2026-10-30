-- +goose Up
-- MySQL 8.4 LTS is the runtime database. Keep the PostgreSQL 17 design under
-- migrations/postgres as the reference model; this file is the operational one.

CREATE TABLE families (
    id            CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    name          VARCHAR(80) NOT NULL,
    surname       VARCHAR(20) NOT NULL,
    motto         VARCHAR(200) NOT NULL DEFAULT '',
    region        VARCHAR(120) NOT NULL DEFAULT '',
    description   VARCHAR(2000) NOT NULL DEFAULT '',
    status        VARCHAR(16) NOT NULL DEFAULT 'active',
    version       INT NOT NULL DEFAULT 1,
    created_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    CONSTRAINT chk_families_name CHECK (CHAR_LENGTH(TRIM(name)) BETWEEN 1 AND 80),
    CONSTRAINT chk_families_surname CHECK (CHAR_LENGTH(TRIM(surname)) BETWEEN 1 AND 20),
    CONSTRAINT chk_families_status CHECK (status IN ('active', 'archived')),
    CONSTRAINT chk_families_version CHECK (version > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='家族空间；所有业务数据的租户边界';

CREATE INDEX ix_families_status ON families (status);

CREATE TABLE users (
    id                      CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    login_name              VARCHAR(80) NOT NULL,
    email                   VARCHAR(254) NULL,
    phone                   VARCHAR(20) NULL,
    password_hash           VARCHAR(255) NOT NULL,
    display_name            VARCHAR(80) NOT NULL,
    status                  VARCHAR(16) NOT NULL DEFAULT 'active',
    failed_login_attempts   INT UNSIGNED NOT NULL DEFAULT 0,
    locked_until            DATETIME(6) NULL,
    last_login_at           DATETIME(6) NULL,
    created_at              DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at              DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_users_login_name (login_name),
    UNIQUE KEY uk_users_email (email),
    UNIQUE KEY uk_users_phone (phone),
    CONSTRAINT chk_users_login_name CHECK (CHAR_LENGTH(TRIM(login_name)) BETWEEN 1 AND 80),
    CONSTRAINT chk_users_email CHECK (email IS NULL OR (LOCATE('@', email) > 1 AND CHAR_LENGTH(email) <= 254)),
    CONSTRAINT chk_users_phone CHECK (phone IS NULL OR phone REGEXP '^[+][1-9][0-9]{7,14}$'),
    CONSTRAINT chk_users_password CHECK (password_hash LIKE '$argon2id$%'),
    CONSTRAINT chk_users_status CHECK (status IN ('active', 'disabled', 'pending'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='全局账户；家庭身份由 family_memberships 表达';

CREATE INDEX ix_users_status ON users (status);

CREATE TABLE branches (
    id            CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    family_id     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    name          VARCHAR(80) NOT NULL,
    description   VARCHAR(1000) NOT NULL DEFAULT '',
    sort_order    INT NOT NULL DEFAULT 0,
    created_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_branches_family_name (family_id, name),
    UNIQUE KEY uk_branches_id_family (id, family_id),
    KEY ix_branches_family_sort (family_id, sort_order),
    CONSTRAINT fk_branches_family FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT chk_branches_name CHECK (CHAR_LENGTH(TRIM(name)) BETWEEN 1 AND 80)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='家支';

CREATE TABLE persons (
    id                    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    family_id             CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    branch_id             CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    surname               VARCHAR(20) NOT NULL,
    given_name            VARCHAR(60) NOT NULL,
    courtesy_name         VARCHAR(60) NOT NULL DEFAULT '',
    alias                 VARCHAR(120) NOT NULL DEFAULT '',
    full_name             VARCHAR(80) GENERATED ALWAYS AS (CONCAT(surname, given_name)) STORED,
    search_text           VARCHAR(300) GENERATED ALWAYS AS (
                              CONCAT_WS(' ', surname, given_name, courtesy_name, alias)
                          ) STORED,
    gender                VARCHAR(16) NOT NULL DEFAULT 'unknown',
    generation_no         SMALLINT NOT NULL,
    birth_order           SMALLINT NULL,
    birth_year            SMALLINT NULL,
    birth_month           SMALLINT NULL,
    birth_day             SMALLINT NULL,
    birth_calendar        VARCHAR(16) NOT NULL DEFAULT 'unknown',
    birth_is_leap_month   TINYINT(1) NOT NULL DEFAULT 0,
    birth_date_text        VARCHAR(80) NOT NULL DEFAULT '',
    death_year            SMALLINT NULL,
    death_month           SMALLINT NULL,
    death_day             SMALLINT NULL,
    death_calendar         VARCHAR(16) NOT NULL DEFAULT 'unknown',
    death_is_leap_month   TINYINT(1) NOT NULL DEFAULT 0,
    death_date_text        VARCHAR(80) NOT NULL DEFAULT '',
    life_status           VARCHAR(16) NOT NULL DEFAULT 'unknown',
    birth_place           VARCHAR(160) NOT NULL DEFAULT '',
    residence             VARCHAR(160) NOT NULL DEFAULT '',
    occupation            VARCHAR(160) NOT NULL DEFAULT '',
    education             VARCHAR(160) NOT NULL DEFAULT '',
    biography             TEXT NOT NULL DEFAULT (''),
    status                VARCHAR(16) NOT NULL DEFAULT 'active',
    version               INT NOT NULL DEFAULT 1,
    created_at            DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at            DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_persons_id_family (id, family_id),
    KEY ix_persons_family_generation (family_id, generation_no, birth_year),
    KEY ix_persons_family_branch (family_id, branch_id),
    KEY ix_persons_family_status (family_id, status),
    FULLTEXT KEY ft_persons_search (search_text) WITH PARSER ngram,
    CONSTRAINT fk_persons_family FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_persons_branch FOREIGN KEY (branch_id, family_id) REFERENCES branches (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT chk_persons_surname CHECK (CHAR_LENGTH(TRIM(surname)) BETWEEN 1 AND 20),
    CONSTRAINT chk_persons_given_name CHECK (CHAR_LENGTH(TRIM(given_name)) BETWEEN 1 AND 60),
    CONSTRAINT chk_persons_gender CHECK (gender IN ('male', 'female', 'other', 'unknown')),
    CONSTRAINT chk_persons_generation CHECK (generation_no BETWEEN 1 AND 99),
    CONSTRAINT chk_persons_birth_order CHECK (birth_order IS NULL OR birth_order > 0),
    CONSTRAINT chk_persons_birth_year CHECK (birth_year IS NULL OR birth_year BETWEEN 1 AND 9999),
    CONSTRAINT chk_persons_birth_month CHECK (birth_month IS NULL OR birth_month BETWEEN 1 AND 12),
    CONSTRAINT chk_persons_birth_day CHECK (birth_day IS NULL OR birth_day BETWEEN 1 AND 31),
    CONSTRAINT chk_persons_birth_calendar CHECK (birth_calendar IN ('gregorian', 'lunar', 'unknown')),
    CONSTRAINT chk_persons_birth_parts CHECK (birth_month IS NULL OR birth_year IS NOT NULL),
    CONSTRAINT chk_persons_birth_parts2 CHECK (birth_day IS NULL OR birth_month IS NOT NULL),
    CONSTRAINT chk_persons_birth_leap CHECK (birth_is_leap_month = 0 OR birth_calendar = 'lunar'),
    CONSTRAINT chk_persons_death_year CHECK (death_year IS NULL OR death_year BETWEEN 1 AND 9999),
    CONSTRAINT chk_persons_death_month CHECK (death_month IS NULL OR death_month BETWEEN 1 AND 12),
    CONSTRAINT chk_persons_death_day CHECK (death_day IS NULL OR death_day BETWEEN 1 AND 31),
    CONSTRAINT chk_persons_death_calendar CHECK (death_calendar IN ('gregorian', 'lunar', 'unknown')),
    CONSTRAINT chk_persons_death_parts CHECK (death_month IS NULL OR death_year IS NOT NULL),
    CONSTRAINT chk_persons_death_parts2 CHECK (death_day IS NULL OR death_month IS NOT NULL),
    CONSTRAINT chk_persons_death_leap CHECK (death_is_leap_month = 0 OR death_calendar = 'lunar'),
    CONSTRAINT chk_persons_life_status CHECK (life_status IN ('living', 'deceased', 'unknown')),
    CONSTRAINT chk_persons_status CHECK (status IN ('active', 'merged', 'archived')),
    CONSTRAINT chk_persons_version CHECK (version > 0),
    CONSTRAINT chk_persons_biography CHECK (CHAR_LENGTH(biography) <= 20000)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='家族人物档案；生卒日期允许部分精度';

CREATE TABLE family_memberships (
    id                  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    family_id           CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id             CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    role                VARCHAR(16) NOT NULL,
    status              VARCHAR(16) NOT NULL DEFAULT 'active',
    person_id           CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    invited_by_user_id  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    joined_at           DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    created_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    owner_slot          CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
                            GENERATED ALWAYS AS (
                                CASE WHEN role = 'owner' AND status = 'active' THEN family_id ELSE NULL END
                            ) STORED,
    active_person_key   VARCHAR(73) CHARACTER SET ascii COLLATE ascii_bin
                            GENERATED ALWAYS AS (
                                CASE WHEN person_id IS NOT NULL AND status <> 'revoked'
                                     THEN CONCAT(family_id, ':', person_id)
                                     ELSE NULL END
                            ) STORED,
    PRIMARY KEY (id),
    UNIQUE KEY uk_memberships_family_user (family_id, user_id),
    UNIQUE KEY uk_memberships_owner (owner_slot),
    UNIQUE KEY uk_memberships_active_person (active_person_key),
    KEY ix_memberships_user_status (user_id, status),
    KEY ix_memberships_person (family_id, person_id),
    CONSTRAINT fk_memberships_family FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_memberships_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
    CONSTRAINT fk_memberships_person FOREIGN KEY (person_id, family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT fk_memberships_inviter FOREIGN KEY (invited_by_user_id) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT chk_memberships_role CHECK (role IN ('owner', 'admin', 'member')),
    CONSTRAINT chk_memberships_status CHECK (status IN ('active', 'invited', 'revoked'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='账户在家族中的角色和状态';

CREATE TABLE parent_child_relationships (
    id            CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    family_id     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    parent_id     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    child_id      CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    parent_role   VARCHAR(16) NOT NULL,
    status        VARCHAR(16) NOT NULL DEFAULT 'active',
    notes         VARCHAR(2000) NOT NULL DEFAULT '',
    created_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    active_father_child CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
                            GENERATED ALWAYS AS (
                                CASE WHEN parent_role = 'father' AND status = 'active' THEN child_id ELSE NULL END
                            ) STORED,
    active_mother_child CHAR(36) CHARACTER SET ascii COLLATE ascii_bin
                            GENERATED ALWAYS AS (
                                CASE WHEN parent_role = 'mother' AND status = 'active' THEN child_id ELSE NULL END
                            ) STORED,
    PRIMARY KEY (id),
    UNIQUE KEY uk_parent_child_pair (family_id, parent_id, child_id),
    UNIQUE KEY uk_parent_child_father (active_father_child),
    UNIQUE KEY uk_parent_child_mother (active_mother_child),
    KEY ix_parent_child_parent (family_id, parent_id),
    KEY ix_parent_child_child (family_id, child_id),
    CONSTRAINT fk_parent_child_family FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_parent_child_parent FOREIGN KEY (parent_id, family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT fk_parent_child_child FOREIGN KEY (child_id, family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT chk_parent_child_self CHECK (parent_id <> child_id),
    CONSTRAINT chk_parent_child_role CHECK (parent_role IN ('father', 'mother', 'parent', 'adoptive', 'step', 'guardian')),
    CONSTRAINT chk_parent_child_status CHECK (status IN ('active', 'ended'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='父母子女关系；同族关系写入保持有序';

-- MySQL has no partial indexes. The generated columns above are the portable
-- equivalent of "one active father / one active mother / one active owner".
-- Relationship edge fields are immutable; end a relationship and insert a new
-- one instead of rewriting history.
-- +goose StatementBegin
CREATE TRIGGER trg_parent_child_cycle_bi
BEFORE INSERT ON parent_child_relationships
FOR EACH ROW
BEGIN
    DECLARE v_cycle INT DEFAULT 0;

    IF NEW.parent_id = NEW.child_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'parent and child must differ';
    END IF;

    WITH RECURSIVE ancestors AS (
        SELECT parent_id
        FROM parent_child_relationships
        WHERE child_id = NEW.parent_id
        UNION
        SELECT p.parent_id
        FROM parent_child_relationships p
        JOIN ancestors a ON p.child_id = a.parent_id
    )
    SELECT COUNT(*) INTO v_cycle
    FROM ancestors
    WHERE parent_id = NEW.child_id;

    IF v_cycle > 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'parent-child relationship would create a cycle';
    END IF;
END;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TRIGGER trg_parent_child_immutable_bu
BEFORE UPDATE ON parent_child_relationships
FOR EACH ROW
BEGIN
    IF NEW.family_id <> OLD.family_id
       OR NEW.parent_id <> OLD.parent_id
       OR NEW.child_id <> OLD.child_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'parent-child edge fields are immutable';
    END IF;
END;
-- +goose StatementEnd

CREATE TABLE spouse_relationships (
    id            CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    family_id     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    person_a_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    person_b_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    status        VARCHAR(16) NOT NULL DEFAULT 'married',
    start_year    SMALLINT NULL,
    end_year      SMALLINT NULL,
    notes         VARCHAR(2000) NOT NULL DEFAULT '',
    created_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at    DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_spouse_pair (family_id, person_a_id, person_b_id),
    KEY ix_spouse_person_a (family_id, person_a_id),
    KEY ix_spouse_person_b (family_id, person_b_id),
    CONSTRAINT fk_spouse_family FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_spouse_person_a FOREIGN KEY (person_a_id, family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT fk_spouse_person_b FOREIGN KEY (person_b_id, family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT chk_spouse_order CHECK (person_a_id < person_b_id),
    CONSTRAINT chk_spouse_status CHECK (status IN ('married', 'divorced', 'widowed', 'unknown')),
    CONSTRAINT chk_spouse_start_year CHECK (start_year IS NULL OR start_year BETWEEN 1 AND 9999),
    CONSTRAINT chk_spouse_end_year CHECK (end_year IS NULL OR end_year BETWEEN 1 AND 9999),
    CONSTRAINT chk_spouse_year_order CHECK (end_year IS NULL OR start_year IS NULL OR end_year >= start_year)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='婚姻关系；A/B 按 UUID 升序规范化';

CREATE TABLE edit_requests (
    id                  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    family_id           CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    requester_user_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    request_type        VARCHAR(32) NOT NULL,
    target_person_id    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    base_version        INT NULL,
    payload             JSON NOT NULL,
    status              VARCHAR(16) NOT NULL DEFAULT 'pending',
    reviewer_user_id    CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    review_note         VARCHAR(2000) NOT NULL DEFAULT '',
    submitted_at        DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    reviewed_at         DATETIME(6) NULL,
    created_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    updated_at          DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY ix_edit_requests_family_status (family_id, status, submitted_at DESC),
    KEY ix_edit_requests_requester (family_id, requester_user_id, submitted_at DESC),
    KEY ix_edit_requests_target (target_person_id, family_id),
    CONSTRAINT fk_edit_requests_family FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_edit_requester FOREIGN KEY (family_id, requester_user_id) REFERENCES family_memberships (family_id, user_id) ON DELETE RESTRICT,
    CONSTRAINT fk_edit_reviewer FOREIGN KEY (family_id, reviewer_user_id) REFERENCES family_memberships (family_id, user_id) ON DELETE RESTRICT,
    CONSTRAINT fk_edit_target FOREIGN KEY (target_person_id, family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CONSTRAINT chk_edit_request_type CHECK (request_type IN (
        'create_person', 'update_person', 'archive_person',
        'add_parent_child', 'end_parent_child',
        'add_spouse', 'end_spouse'
    )),
    CONSTRAINT chk_edit_base_version CHECK (base_version IS NULL OR base_version > 0),
    CONSTRAINT chk_edit_payload_object CHECK (JSON_TYPE(payload) = 'OBJECT'),
    CONSTRAINT chk_edit_status CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    CONSTRAINT chk_edit_review_state CHECK (
        (status = 'pending' AND reviewer_user_id IS NULL AND reviewed_at IS NULL)
        OR (status = 'approved' AND reviewer_user_id IS NOT NULL AND reviewed_at IS NOT NULL)
        OR (status = 'rejected' AND reviewer_user_id IS NOT NULL AND reviewed_at IS NOT NULL)
        OR status = 'cancelled'
    )
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='资料修改申请；审核通过后在同一事务应用';

CREATE TABLE audit_logs (
    id                BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    family_id         CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    actor_user_id     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    action            VARCHAR(80) NOT NULL,
    entity_type       VARCHAR(80) NOT NULL,
    entity_id         CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    edit_request_id   CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    before_data       JSON NULL,
    after_data        JSON NULL,
    ip                VARCHAR(45) NULL,
    user_agent        VARCHAR(512) NULL,
    trace_id          VARCHAR(128) NULL,
    created_at        DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    KEY ix_audit_logs_family_time (family_id, created_at DESC),
    KEY ix_audit_logs_entity (family_id, entity_type, entity_id),
    CONSTRAINT fk_audit_family FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE RESTRICT,
    CONSTRAINT fk_audit_actor FOREIGN KEY (actor_user_id) REFERENCES users (id) ON DELETE SET NULL,
    CONSTRAINT fk_audit_request FOREIGN KEY (edit_request_id) REFERENCES edit_requests (id) ON DELETE SET NULL,
    CONSTRAINT chk_audit_action CHECK (CHAR_LENGTH(action) BETWEEN 1 AND 80),
    CONSTRAINT chk_audit_entity CHECK (CHAR_LENGTH(entity_type) BETWEEN 1 AND 80),
    CONSTRAINT chk_audit_trace CHECK (trace_id IS NULL OR CHAR_LENGTH(trace_id) <= 128)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='追加写审计日志；触发器禁止更新和删除';

-- +goose StatementBegin
CREATE TRIGGER trg_audit_logs_no_update
BEFORE UPDATE ON audit_logs
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_logs is append-only';
END;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE TRIGGER trg_audit_logs_no_delete
BEFORE DELETE ON audit_logs
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'audit_logs is append-only';
END;
-- +goose StatementEnd

CREATE TABLE user_sessions (
    id              CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    user_id         CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    token_hash      BINARY(32) NOT NULL,
    expires_at      DATETIME(6) NOT NULL,
    revoked_at      DATETIME(6) NULL,
    last_used_at    DATETIME(6) NULL,
    ip              VARCHAR(45) NULL,
    user_agent      VARCHAR(512) NULL,
    created_at      DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    PRIMARY KEY (id),
    UNIQUE KEY uk_sessions_token_hash (token_hash),
    KEY ix_sessions_user_active (user_id, expires_at DESC),
    CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT chk_sessions_expiry CHECK (expires_at > created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci COMMENT='不透明会话令牌哈希；不保存明文令牌';

-- +goose Down
DROP TRIGGER IF EXISTS trg_audit_logs_no_delete;
DROP TRIGGER IF EXISTS trg_audit_logs_no_update;
DROP TRIGGER IF EXISTS trg_parent_child_immutable_bu;
DROP TRIGGER IF EXISTS trg_parent_child_cycle_bi;

DROP TABLE IF EXISTS user_sessions;
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS edit_requests;
DROP TABLE IF EXISTS spouse_relationships;
DROP TABLE IF EXISTS parent_child_relationships;
DROP TABLE IF EXISTS family_memberships;
DROP TABLE IF EXISTS persons;
DROP TABLE IF EXISTS branches;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS families;
