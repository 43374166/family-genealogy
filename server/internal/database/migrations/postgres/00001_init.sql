-- +goose Up

CREATE EXTENSION IF NOT EXISTS citext;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- +goose StatementBegin
CREATE FUNCTION set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;
-- +goose StatementEnd

CREATE TABLE families (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name          text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 1 AND 80),
    surname       text NOT NULL CHECK (char_length(btrim(surname)) BETWEEN 1 AND 20),
    motto         text NOT NULL DEFAULT '' CHECK (char_length(motto) <= 200),
    region        text NOT NULL DEFAULT '' CHECK (char_length(region) <= 120),
    description   text NOT NULL DEFAULT '' CHECK (char_length(description) <= 2000),
    status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived')),
    version       integer NOT NULL DEFAULT 1 CHECK (version > 0),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_families_status ON families (status);

CREATE TABLE users (
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    login_name              citext NOT NULL UNIQUE,
    email                   citext UNIQUE,
    phone                   text UNIQUE,
    password_hash           text NOT NULL CHECK (password_hash LIKE '$argon2id$%'),
    display_name            text NOT NULL CHECK (char_length(btrim(display_name)) BETWEEN 1 AND 80),
    status                  text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'disabled', 'pending')),
    failed_login_attempts   integer NOT NULL DEFAULT 0 CHECK (failed_login_attempts >= 0),
    locked_until            timestamptz,
    last_login_at           timestamptz,
    created_at              timestamptz NOT NULL DEFAULT now(),
    updated_at              timestamptz NOT NULL DEFAULT now(),
    CHECK (char_length(btrim(login_name::text)) BETWEEN 1 AND 80),
    CHECK (email IS NULL OR (position('@' IN email) > 1 AND char_length(email::text) <= 254)),
    CHECK (phone IS NULL OR phone ~ '^\+[1-9][0-9]{7,14}$')
);

CREATE INDEX ix_users_status ON users (status);

CREATE TABLE branches (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id     uuid NOT NULL REFERENCES families (id) ON DELETE RESTRICT,
    name          text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 1 AND 80),
    description   text NOT NULL DEFAULT '' CHECK (char_length(description) <= 1000),
    sort_order    integer NOT NULL DEFAULT 0,
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (family_id, name),
    UNIQUE (id, family_id)
);

CREATE INDEX ix_branches_family ON branches (family_id, sort_order);

CREATE TABLE persons (
    id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id             uuid NOT NULL REFERENCES families (id) ON DELETE RESTRICT,
    branch_id             uuid,
    surname               text NOT NULL CHECK (char_length(btrim(surname)) BETWEEN 1 AND 20),
    given_name            text NOT NULL CHECK (char_length(btrim(given_name)) BETWEEN 1 AND 60),
    courtesy_name         text NOT NULL DEFAULT '' CHECK (char_length(courtesy_name) <= 60),
    alias                 text NOT NULL DEFAULT '' CHECK (char_length(alias) <= 120),
    full_name             text GENERATED ALWAYS AS (surname || given_name) STORED,
    search_text           text GENERATED ALWAYS AS (
                              surname || given_name || ' ' || courtesy_name || ' ' || alias
                          ) STORED,
    gender                text NOT NULL DEFAULT 'unknown' CHECK (gender IN ('male', 'female', 'other', 'unknown')),
    generation_no         smallint NOT NULL CHECK (generation_no BETWEEN 1 AND 99),
    birth_order           smallint CHECK (birth_order IS NULL OR birth_order > 0),
    birth_year            smallint CHECK (birth_year IS NULL OR birth_year BETWEEN 1 AND 9999),
    birth_month           smallint CHECK (birth_month IS NULL OR birth_month BETWEEN 1 AND 12),
    birth_day             smallint CHECK (birth_day IS NULL OR birth_day BETWEEN 1 AND 31),
    birth_calendar        text NOT NULL DEFAULT 'unknown' CHECK (birth_calendar IN ('gregorian', 'lunar', 'unknown')),
    birth_is_leap_month   boolean NOT NULL DEFAULT false,
    birth_date_text        text NOT NULL DEFAULT '' CHECK (char_length(birth_date_text) <= 80),
    death_year            smallint CHECK (death_year IS NULL OR death_year BETWEEN 1 AND 9999),
    death_month           smallint CHECK (death_month IS NULL OR death_month BETWEEN 1 AND 12),
    death_day             smallint CHECK (death_day IS NULL OR death_day BETWEEN 1 AND 31),
    death_calendar         text NOT NULL DEFAULT 'unknown' CHECK (death_calendar IN ('gregorian', 'lunar', 'unknown')),
    death_is_leap_month   boolean NOT NULL DEFAULT false,
    death_date_text        text NOT NULL DEFAULT '' CHECK (char_length(death_date_text) <= 80),
    life_status           text NOT NULL DEFAULT 'unknown' CHECK (life_status IN ('living', 'deceased', 'unknown')),
    birth_place           text NOT NULL DEFAULT '' CHECK (char_length(birth_place) <= 160),
    residence             text NOT NULL DEFAULT '' CHECK (char_length(residence) <= 160),
    occupation            text NOT NULL DEFAULT '' CHECK (char_length(occupation) <= 160),
    education             text NOT NULL DEFAULT '' CHECK (char_length(education) <= 160),
    biography             text NOT NULL DEFAULT '' CHECK (char_length(biography) <= 20000),
    status                text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'merged', 'archived')),
    version               integer NOT NULL DEFAULT 1 CHECK (version > 0),
    created_at            timestamptz NOT NULL DEFAULT now(),
    updated_at            timestamptz NOT NULL DEFAULT now(),
    UNIQUE (id, family_id),
    FOREIGN KEY (branch_id, family_id) REFERENCES branches (id, family_id) ON DELETE RESTRICT,
    CHECK (birth_month IS NULL OR birth_year IS NOT NULL),
    CHECK (birth_day IS NULL OR birth_month IS NOT NULL),
    CHECK (death_month IS NULL OR death_year IS NOT NULL),
    CHECK (death_day IS NULL OR death_month IS NOT NULL),
    CHECK (NOT birth_is_leap_month OR birth_calendar = 'lunar'),
    CHECK (NOT death_is_leap_month OR death_calendar = 'lunar'),
    -- Full Gregorian dates must be real dates. make_date raises on invalid
    -- month/day combinations instead of silently storing 31 February.
    CHECK (birth_calendar <> 'gregorian' OR birth_year IS NULL OR birth_month IS NULL OR birth_day IS NULL OR make_date(birth_year, birth_month, birth_day) IS NOT NULL),
    CHECK (death_calendar <> 'gregorian' OR death_year IS NULL OR death_month IS NULL OR death_day IS NULL OR make_date(death_year, death_month, death_day) IS NOT NULL)
);

CREATE INDEX ix_persons_family_generation ON persons (family_id, generation_no, birth_year);
CREATE INDEX ix_persons_family_branch ON persons (family_id, branch_id);
CREATE INDEX ix_persons_family_status ON persons (family_id, status);
CREATE INDEX ix_persons_full_name_trgm ON persons USING gin (search_text gin_trgm_ops);

CREATE TABLE family_memberships (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id           uuid NOT NULL REFERENCES families (id) ON DELETE RESTRICT,
    user_id             uuid NOT NULL REFERENCES users (id) ON DELETE RESTRICT,
    role                text NOT NULL CHECK (role IN ('owner', 'admin', 'member')),
    status              text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'invited', 'revoked')),
    person_id           uuid,
    invited_by_user_id  uuid REFERENCES users (id) ON DELETE SET NULL,
    joined_at           timestamptz NOT NULL DEFAULT now(),
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    UNIQUE (family_id, user_id),
    FOREIGN KEY (person_id, family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT
);

CREATE UNIQUE INDEX ux_memberships_one_owner
    ON family_memberships (family_id)
    WHERE role = 'owner' AND status = 'active';

CREATE UNIQUE INDEX ux_memberships_one_active_person
    ON family_memberships (family_id, person_id)
    WHERE person_id IS NOT NULL AND status <> 'revoked';

CREATE INDEX ix_memberships_user_status ON family_memberships (user_id, status);

CREATE TABLE parent_child_relationships (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id     uuid NOT NULL REFERENCES families (id) ON DELETE RESTRICT,
    parent_id     uuid NOT NULL,
    child_id      uuid NOT NULL,
    parent_role   text NOT NULL CHECK (parent_role IN ('father', 'mother', 'parent', 'adoptive', 'step', 'guardian')),
    status        text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'ended')),
    notes         text NOT NULL DEFAULT '' CHECK (char_length(notes) <= 2000),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (family_id, parent_id, child_id),
    FOREIGN KEY (parent_id, family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    FOREIGN KEY (child_id, family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CHECK (parent_id <> child_id)
);

CREATE UNIQUE INDEX ux_parent_child_one_father
    ON parent_child_relationships (family_id, child_id)
    WHERE parent_role = 'father' AND status = 'active';

CREATE UNIQUE INDEX ux_parent_child_one_mother
    ON parent_child_relationships (family_id, child_id)
    WHERE parent_role = 'mother' AND status = 'active';

CREATE INDEX ix_parent_child_parent ON parent_child_relationships (family_id, parent_id);
CREATE INDEX ix_parent_child_child ON parent_child_relationships (family_id, child_id);

CREATE TABLE spouse_relationships (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id     uuid NOT NULL REFERENCES families (id) ON DELETE RESTRICT,
    person_a_id   uuid NOT NULL,
    person_b_id   uuid NOT NULL,
    status        text NOT NULL DEFAULT 'married' CHECK (status IN ('married', 'divorced', 'widowed', 'unknown')),
    start_year    smallint CHECK (start_year IS NULL OR start_year BETWEEN 1 AND 9999),
    end_year      smallint CHECK (end_year IS NULL OR end_year BETWEEN 1 AND 9999),
    notes         text NOT NULL DEFAULT '' CHECK (char_length(notes) <= 2000),
    created_at    timestamptz NOT NULL DEFAULT now(),
    updated_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (family_id, person_a_id, person_b_id),
    FOREIGN KEY (person_a_id, family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    FOREIGN KEY (person_b_id, family_id) REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CHECK (person_a_id < person_b_id),
    CHECK (end_year IS NULL OR start_year IS NULL OR end_year >= start_year)
);

CREATE INDEX ix_spouse_person_a ON spouse_relationships (family_id, person_a_id);
CREATE INDEX ix_spouse_person_b ON spouse_relationships (family_id, person_b_id);

CREATE TABLE edit_requests (
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id           uuid NOT NULL REFERENCES families (id) ON DELETE RESTRICT,
    requester_user_id   uuid NOT NULL,
    request_type        text NOT NULL CHECK (request_type IN (
                            'create_person', 'update_person', 'archive_person',
                            'add_parent_child', 'end_parent_child',
                            'add_spouse', 'end_spouse'
                        )),
    target_person_id    uuid,
    base_version        integer CHECK (base_version IS NULL OR base_version > 0),
    payload             jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(payload) = 'object'),
    status              text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
    reviewer_user_id    uuid,
    review_note         text NOT NULL DEFAULT '' CHECK (char_length(review_note) <= 2000),
    submitted_at        timestamptz NOT NULL DEFAULT now(),
    reviewed_at         timestamptz,
    created_at          timestamptz NOT NULL DEFAULT now(),
    updated_at          timestamptz NOT NULL DEFAULT now(),
    FOREIGN KEY (family_id, requester_user_id)
        REFERENCES family_memberships (family_id, user_id) ON DELETE RESTRICT,
    FOREIGN KEY (family_id, reviewer_user_id)
        REFERENCES family_memberships (family_id, user_id) ON DELETE RESTRICT,
    FOREIGN KEY (target_person_id, family_id)
        REFERENCES persons (id, family_id) ON DELETE RESTRICT,
    CHECK (
        (status = 'pending' AND reviewer_user_id IS NULL AND reviewed_at IS NULL)
        OR (status = 'approved' AND reviewer_user_id IS NOT NULL AND reviewed_at IS NOT NULL)
        OR (status = 'rejected' AND reviewer_user_id IS NOT NULL AND reviewed_at IS NOT NULL)
        OR status = 'cancelled'
    )
);

CREATE INDEX ix_edit_requests_family_status ON edit_requests (family_id, status, submitted_at DESC);
CREATE INDEX ix_edit_requests_requester ON edit_requests (family_id, requester_user_id, submitted_at DESC);

CREATE TABLE audit_logs (
    id                bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    family_id         uuid NOT NULL REFERENCES families (id) ON DELETE RESTRICT,
    actor_user_id     uuid REFERENCES users (id) ON DELETE SET NULL,
    action            text NOT NULL CHECK (char_length(action) BETWEEN 1 AND 80),
    entity_type       text NOT NULL CHECK (char_length(entity_type) BETWEEN 1 AND 80),
    entity_id         uuid,
    edit_request_id   uuid REFERENCES edit_requests (id) ON DELETE SET NULL,
    before_data       jsonb CHECK (before_data IS NULL OR jsonb_typeof(before_data) = 'object'),
    after_data        jsonb CHECK (after_data IS NULL OR jsonb_typeof(after_data) = 'object'),
    ip                inet,
    user_agent        text,
    trace_id          text CHECK (trace_id IS NULL OR char_length(trace_id) <= 128),
    created_at        timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_audit_logs_family_time ON audit_logs (family_id, created_at DESC);
CREATE INDEX ix_audit_logs_entity ON audit_logs (family_id, entity_type, entity_id);

CREATE TABLE user_sessions (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         uuid NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    token_hash      bytea NOT NULL UNIQUE CHECK (octet_length(token_hash) = 32),
    expires_at      timestamptz NOT NULL,
    revoked_at      timestamptz,
    last_used_at    timestamptz,
    ip              inet,
    user_agent      text,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_user_sessions_user_active ON user_sessions (user_id, expires_at DESC)
    WHERE revoked_at IS NULL;

-- +goose StatementBegin
CREATE FUNCTION enforce_parent_child_acyclic()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    creates_cycle boolean;
BEGIN
    IF NEW.parent_id = NEW.child_id THEN
        RAISE EXCEPTION 'parent and child must be different persons'
            USING ERRCODE = '23514';
    END IF;

    -- Serialize relationship writes per family so two concurrent inserts cannot
    -- each pass the cycle check and then form a cycle together.
    PERFORM pg_advisory_xact_lock(hashtextextended(NEW.family_id::text, 0));

    WITH RECURSIVE ancestors AS (
        SELECT pcr.parent_id
        FROM parent_child_relationships pcr
        WHERE pcr.child_id = NEW.parent_id
          AND pcr.id <> NEW.id
        UNION
        SELECT pcr.parent_id
        FROM parent_child_relationships pcr
        JOIN ancestors a ON pcr.child_id = a.parent_id
        WHERE pcr.id <> NEW.id
    )
    SELECT EXISTS (
        SELECT 1 FROM ancestors WHERE parent_id = NEW.child_id
    ) INTO creates_cycle;

    IF creates_cycle THEN
        RAISE EXCEPTION 'parent-child relationship would create a cycle'
            USING ERRCODE = '23514';
    END IF;

    RETURN NEW;
END;
$$;
-- +goose StatementEnd

-- +goose StatementBegin
CREATE FUNCTION forbid_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'audit_logs is append-only'
        USING ERRCODE = '55000';
END;
$$;
-- +goose StatementEnd

CREATE TRIGGER trg_families_updated_at
BEFORE UPDATE ON families
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_branches_updated_at
BEFORE UPDATE ON branches
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_persons_updated_at
BEFORE UPDATE ON persons
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_memberships_updated_at
BEFORE UPDATE ON family_memberships
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_parent_child_updated_at
BEFORE UPDATE ON parent_child_relationships
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_spouse_updated_at
BEFORE UPDATE ON spouse_relationships
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_edit_requests_updated_at
BEFORE UPDATE ON edit_requests
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_parent_child_acyclic
BEFORE INSERT OR UPDATE
ON parent_child_relationships
FOR EACH ROW EXECUTE FUNCTION enforce_parent_child_acyclic();

CREATE TRIGGER trg_audit_logs_no_update
BEFORE UPDATE OR DELETE ON audit_logs
FOR EACH ROW EXECUTE FUNCTION forbid_audit_mutation();

COMMENT ON TABLE families IS '家族空间；所有业务数据的租户边界';
COMMENT ON TABLE users IS '全局账户；家庭身份由 family_memberships 表达';
COMMENT ON TABLE family_memberships IS '账户在家族中的角色和状态';
COMMENT ON TABLE persons IS '家族人物档案；生卒日期允许部分精度';
COMMENT ON COLUMN persons.birth_is_leap_month IS '农历闰月标记；公历恒为 false';
COMMENT ON TABLE parent_child_relationships IS '父母子女关系；数据库触发器阻止环路';
COMMENT ON TABLE spouse_relationships IS '婚姻关系；A/B 按 UUID 升序规范化';
COMMENT ON TABLE edit_requests IS '资料修改申请；审核通过后在同一事务应用';
COMMENT ON TABLE audit_logs IS '追加写审计日志；数据库触发器禁止更新和删除';
COMMENT ON TABLE user_sessions IS '不透明会话令牌哈希；不保存明文令牌';

-- +goose Down

DROP TRIGGER IF EXISTS trg_audit_logs_no_update ON audit_logs;
DROP TRIGGER IF EXISTS trg_parent_child_acyclic ON parent_child_relationships;
DROP TRIGGER IF EXISTS trg_edit_requests_updated_at ON edit_requests;
DROP TRIGGER IF EXISTS trg_spouse_updated_at ON spouse_relationships;
DROP TRIGGER IF EXISTS trg_parent_child_updated_at ON parent_child_relationships;
DROP TRIGGER IF EXISTS trg_memberships_updated_at ON family_memberships;
DROP TRIGGER IF EXISTS trg_persons_updated_at ON persons;
DROP TRIGGER IF EXISTS trg_branches_updated_at ON branches;
DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
DROP TRIGGER IF EXISTS trg_families_updated_at ON families;

DROP FUNCTION IF EXISTS forbid_audit_mutation();
DROP FUNCTION IF EXISTS enforce_parent_child_acyclic();
DROP FUNCTION IF EXISTS set_updated_at();

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

-- Extensions are intentionally left installed: they may be shared by other schemas.
