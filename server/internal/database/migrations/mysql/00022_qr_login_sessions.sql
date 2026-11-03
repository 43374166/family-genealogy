-- +goose Up
CREATE TABLE auth_qr_sessions (
    id                  CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
    secret_hash         BINARY(32) NOT NULL,
    status              VARCHAR(16) NOT NULL DEFAULT 'pending',
    requester_ip        VARCHAR(45) NOT NULL DEFAULT '',
    requester_city      VARCHAR(80) NOT NULL DEFAULT '',
    requester_region    VARCHAR(80) NOT NULL DEFAULT '',
    requester_country   VARCHAR(80) NOT NULL DEFAULT '',
    requester_user_agent VARCHAR(512) NOT NULL DEFAULT '',
    requester_device    VARCHAR(120) NOT NULL DEFAULT '',
    scanned_user_id     CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    user_id             CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    family_id           CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NULL,
    created_at          DATETIME(6) NOT NULL,
    expires_at          DATETIME(6) NOT NULL,
    scanned_at          DATETIME(6) NULL,
    confirmed_at        DATETIME(6) NULL,
    consumed_at         DATETIME(6) NULL,
    PRIMARY KEY (id),
    KEY ix_auth_qr_expiry (expires_at),
    KEY ix_auth_qr_ip_time (requester_ip, created_at),
    CONSTRAINT fk_auth_qr_scanned_user FOREIGN KEY (scanned_user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_auth_qr_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
    CONSTRAINT fk_auth_qr_family FOREIGN KEY (family_id) REFERENCES families (id) ON DELETE CASCADE,
    CONSTRAINT chk_auth_qr_status CHECK (status IN ('pending', 'scanned', 'confirmed', 'consumed', 'expired', 'cancelled'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Web 扫码登录会话；二维码仅携带一次性 secret，服务端只存哈希';

-- +goose Down
DROP TABLE IF EXISTS auth_qr_sessions;
