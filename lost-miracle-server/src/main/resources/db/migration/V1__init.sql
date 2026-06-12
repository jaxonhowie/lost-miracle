CREATE TABLE `user` (
    `id`            BIGINT       NOT NULL PRIMARY KEY,
    `username`      VARCHAR(64)  NOT NULL,
    `password_hash` VARCHAR(255) NOT NULL,
    `status`        TINYINT      NOT NULL DEFAULT 1 COMMENT '1=active 0=banned',
    `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `character` (
    `id`                  BIGINT       NOT NULL PRIMARY KEY,
    `user_id`             BIGINT       NOT NULL,
    `name`                VARCHAR(32)  NOT NULL DEFAULT '冒险者',
    `player_class`        VARCHAR(16)  NOT NULL DEFAULT 'warrior',
    `level`               INT          NOT NULL DEFAULT 1,
    `power_score`         INT          NOT NULL DEFAULT 0,
    `current_dungeon_id`  VARCHAR(32)  NOT NULL DEFAULT 'bone_crypt',
    `last_login_at`       DATETIME     NULL,
    `created_at`          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at`          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX `idx_character_user_id` (`user_id`),
    CONSTRAINT `fk_character_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `character_save` (
    `character_id`      BIGINT       NOT NULL PRIMARY KEY,
    `save_version`      BIGINT       NOT NULL DEFAULT 1,
    `save_json`         JSON         NOT NULL,
    `checksum`          CHAR(64)     NOT NULL,
    `client_updated_at` BIGINT       NOT NULL,
    `server_updated_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT `fk_save_character` FOREIGN KEY (`character_id`) REFERENCES `character` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `leaderboard_snapshot` (
    `id`           BIGINT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `board_type`   VARCHAR(32) NOT NULL,
    `season`       VARCHAR(16) NOT NULL DEFAULT 'all',
    `character_id` BIGINT      NOT NULL,
    `score`        BIGINT      NOT NULL,
    `rank`         INT         NOT NULL,
    `snapshot_at`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_leaderboard_board_season` (`board_type`, `season`, `rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
