-- V4: 移除外键约束，保留索引，关联关系由业务逻辑保证

ALTER TABLE `character` DROP FOREIGN KEY `fk_character_user`;
ALTER TABLE `character_save` DROP FOREIGN KEY `fk_save_character`;
ALTER TABLE `achievement_progress` DROP FOREIGN KEY `fk_achievement_progress_character`;
ALTER TABLE `mail` DROP FOREIGN KEY `fk_mail_character`;
