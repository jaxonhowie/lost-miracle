CREATE TABLE game_config (
    config_key     VARCHAR(64)  NOT NULL PRIMARY KEY,
    draft_json     JSON         NOT NULL,
    published_json JSON         NULL,
    description    VARCHAR(255) NULL,
    updated_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE game_config_publish (
    id             BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    version        BIGINT       NOT NULL UNIQUE,
    published_by   BIGINT       NOT NULL,
    note           VARCHAR(255) NULL,
    snapshot_json  JSON         NOT NULL,
    published_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_config_publish_time (published_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE game_config_meta (
    id             TINYINT      NOT NULL PRIMARY KEY DEFAULT 1,
    current_version BIGINT      NOT NULL DEFAULT 0,
    updated_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO game_config_meta (id, current_version) VALUES (1, 0);
