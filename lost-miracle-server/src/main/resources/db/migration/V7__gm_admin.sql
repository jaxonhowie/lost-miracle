CREATE TABLE gm_account (
    id            BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(64)  NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(16)  NOT NULL DEFAULT 'operator' COMMENT 'viewer | operator | super',
    status        TINYINT      NOT NULL DEFAULT 1 COMMENT '1=active 0=disabled',
    created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_gm_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE gm_audit_log (
    id              BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    gm_account_id   BIGINT       NOT NULL,
    action          VARCHAR(64)  NOT NULL,
    target_type     VARCHAR(32)  NOT NULL,
    target_id       VARCHAR(64)  NOT NULL,
    detail_json     JSON         NULL,
    ip              VARCHAR(45)  NULL,
    created_at      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_gm_audit_time (created_at),
    INDEX idx_gm_audit_target (target_type, target_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
