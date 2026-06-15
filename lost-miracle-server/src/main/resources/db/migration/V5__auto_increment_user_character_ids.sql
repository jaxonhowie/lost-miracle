-- user / character 主键改为自增，修复注册与创建角色时 id 为空导致插入失败

ALTER TABLE `user` MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;
ALTER TABLE `character` MODIFY `id` BIGINT NOT NULL AUTO_INCREMENT;
