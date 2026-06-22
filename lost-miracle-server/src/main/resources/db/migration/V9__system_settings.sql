CREATE TABLE system_settings (
    `key`       VARCHAR(64)  NOT NULL PRIMARY KEY,
    `value`     TEXT         NULL,
    updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO system_settings (`key`, `value`) VALUES
    ('maintenance_mode', 'false'),
    ('maintenance_message', '服务器维护中，请稍后再试');
