CREATE TABLE `character_save_snapshot` (
    `id`            BIGINT   NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `character_id`  BIGINT   NOT NULL,
    `save_version`  BIGINT   NOT NULL,
    `save_json`     JSON     NOT NULL,
    `created_at`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX `idx_snapshot_character_version` (`character_id`, `save_version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
