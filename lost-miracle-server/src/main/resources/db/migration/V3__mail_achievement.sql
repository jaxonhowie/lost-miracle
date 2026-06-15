CREATE TABLE `achievement_progress` (
    `id`           BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `character_id` BIGINT       NOT NULL,
    `achievement_id` VARCHAR(64) NOT NULL,
    `progress`     INT          NOT NULL DEFAULT 0,
    `completed`    TINYINT      NOT NULL DEFAULT 0,
    `updated_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_character_achievement` (`character_id`, `achievement_id`),
    CONSTRAINT `fk_achievement_progress_character` FOREIGN KEY (`character_id`) REFERENCES `character` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE `mail` (
    `id`           BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `character_id` BIGINT       NOT NULL,
    `title`        VARCHAR(128) NOT NULL,
    `body`         VARCHAR(512) NOT NULL DEFAULT '',
    `attachments`  JSON         NULL,
    `claimed`      TINYINT      NOT NULL DEFAULT 0,
    `created_at`   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `claimed_at`   DATETIME     NULL,
    INDEX `idx_mail_character` (`character_id`, `claimed`),
    CONSTRAINT `fk_mail_character` FOREIGN KEY (`character_id`) REFERENCES `character` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
