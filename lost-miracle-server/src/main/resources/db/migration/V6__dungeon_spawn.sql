CREATE TABLE `dungeon_spawn_slot` (
    `id`                     BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    `dungeon_id`             VARCHAR(32)  NOT NULL,
    `spawn_type`             VARCHAR(16)  NOT NULL COMMENT 'normal|elite|boss',
    `monster_id`             VARCHAR(64)  NOT NULL,
    `slot_index`             INT          NOT NULL DEFAULT 0,
    `respawn_at`             BIGINT       NOT NULL DEFAULT 0,
    `engaged_character_id`   BIGINT       NULL,
    `updated_at`             DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_dungeon_spawn` (`dungeon_id`, `spawn_type`, `monster_id`, `slot_index`),
    INDEX `idx_dungeon_spawn_lookup` (`dungeon_id`, `spawn_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
