CREATE TABLE `user` (
    id            BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(64)  NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    status        TINYINT      NOT NULL DEFAULT 1,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (username)
);

CREATE TABLE `character` (
    id                 BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    user_id            BIGINT       NOT NULL,
    name               VARCHAR(32)  NOT NULL DEFAULT '冒险者',
    player_class       VARCHAR(16)  NOT NULL DEFAULT 'warrior',
    level              INT          NOT NULL DEFAULT 1,
    power_score        INT          NOT NULL DEFAULT 0,
    current_dungeon_id VARCHAR(32)  NOT NULL DEFAULT 'bone_crypt',
    last_login_at      TIMESTAMP    NULL,
    created_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at         TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_character_user_id ON `character` (user_id);

CREATE TABLE character_save (
    character_id      BIGINT    NOT NULL PRIMARY KEY,
    save_version      BIGINT    NOT NULL DEFAULT 1,
    save_json         CLOB      NOT NULL,
    checksum          CHAR(64)  NOT NULL,
    client_updated_at BIGINT    NOT NULL,
    server_updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE character_save_snapshot (
    id           BIGINT    NOT NULL AUTO_INCREMENT PRIMARY KEY,
    character_id BIGINT    NOT NULL,
    save_version BIGINT    NOT NULL,
    save_json    CLOB      NOT NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_snapshot_character_version ON character_save_snapshot (character_id, save_version);

CREATE TABLE achievement_progress (
    id             BIGINT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
    character_id   BIGINT      NOT NULL,
    achievement_id VARCHAR(64) NOT NULL,
    progress       INT         NOT NULL DEFAULT 0,
    completed      TINYINT     NOT NULL DEFAULT 0,
    updated_at     TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (character_id, achievement_id)
);

CREATE TABLE mail (
    id           BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    character_id BIGINT       NOT NULL,
    title        VARCHAR(128) NOT NULL,
    body         VARCHAR(512) NOT NULL DEFAULT '',
    attachments  CLOB         NULL,
    claimed      TINYINT      NOT NULL DEFAULT 0,
    created_at   TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    claimed_at   TIMESTAMP    NULL
);
CREATE INDEX idx_mail_character ON mail (character_id, claimed);

CREATE TABLE dungeon_spawn_slot (
    id                   BIGINT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
    dungeon_id           VARCHAR(32) NOT NULL,
    spawn_type           VARCHAR(16) NOT NULL,
    monster_id           VARCHAR(64) NOT NULL,
    slot_index           INT         NOT NULL DEFAULT 0,
    respawn_at           BIGINT      NOT NULL DEFAULT 0,
    engaged_character_id BIGINT      NULL,
    updated_at           TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (dungeon_id, spawn_type, monster_id, slot_index)
);
CREATE INDEX idx_dungeon_spawn_lookup ON dungeon_spawn_slot (dungeon_id, spawn_type);

CREATE TABLE gm_account (
    id            BIGINT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(64)  NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          VARCHAR(16)  NOT NULL DEFAULT 'operator',
    status        TINYINT      NOT NULL DEFAULT 1,
    created_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (username)
);

CREATE TABLE gm_audit_log (
    id            BIGINT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
    gm_account_id BIGINT      NOT NULL,
    action        VARCHAR(64) NOT NULL,
    target_type   VARCHAR(32) NOT NULL,
    target_id     VARCHAR(64) NOT NULL,
    detail_json   CLOB        NULL,
    ip            VARCHAR(45) NULL,
    created_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_gm_audit_time ON gm_audit_log (created_at);
CREATE INDEX idx_gm_audit_target ON gm_audit_log (target_type, target_id);

CREATE TABLE game_config (
    config_key     VARCHAR(64)  NOT NULL PRIMARY KEY,
    draft_json     CLOB         NOT NULL,
    published_json CLOB         NULL,
    description    VARCHAR(255) NULL,
    updated_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE game_config_publish (
    id            BIGINT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
    version       BIGINT      NOT NULL UNIQUE,
    published_by  BIGINT      NOT NULL,
    note          VARCHAR(255) NULL,
    snapshot_json CLOB        NOT NULL,
    published_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_config_publish_time ON game_config_publish (published_at);

CREATE TABLE game_config_meta (
    id              TINYINT   NOT NULL PRIMARY KEY,
    current_version BIGINT    NOT NULL DEFAULT 0,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO game_config_meta (id, current_version) VALUES (1, 0);

CREATE TABLE leaderboard_snapshot (
    id           BIGINT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
    board_type   VARCHAR(32) NOT NULL,
    season       VARCHAR(16) NOT NULL DEFAULT 'all',
    character_id BIGINT      NOT NULL,
    score        BIGINT      NOT NULL,
    rank         INT         NOT NULL,
    snapshot_at  TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX idx_leaderboard_board_season ON leaderboard_snapshot (board_type, season, rank);
