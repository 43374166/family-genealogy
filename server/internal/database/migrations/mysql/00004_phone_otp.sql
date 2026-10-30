-- +goose Up
CREATE TABLE phone_verification_codes (
    id              CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT (UUID()),
    phone           VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    user_id         CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    purpose         VARCHAR(16) NOT NULL,
    code_hash       CHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    expires_at      DATETIME(6) NOT NULL,
    attempts        INT UNSIGNED NOT NULL DEFAULT 0,
    max_attempts    INT UNSIGNED NOT NULL DEFAULT 5,
    used_at         DATETIME(6) NULL,
    created_at      DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
    ip              VARCHAR(45) NOT NULL DEFAULT '',
    PRIMARY KEY (id),
    KEY ix_phone_otp_lookup (phone, purpose, created_at DESC),
    KEY ix_phone_otp_user (user_id, purpose, created_at DESC),
    CONSTRAINT fk_phone_otp_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT chk_phone_otp_purpose CHECK (purpose IN ('login', 'bind')),
    CONSTRAINT chk_phone_otp_attempts CHECK (attempts <= max_attempts)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='手机验证码；只保存 HMAC 摘要，不保存明文';

-- +goose Down
DROP TABLE IF EXISTS phone_verification_codes;
