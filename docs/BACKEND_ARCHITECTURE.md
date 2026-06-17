# 失落奇迹 — 服务端架构设计

> **版本** v1.0 | 2026-06-12  
> 本文档描述在线化后端技术选型与总体设计，与 [`DESIGN.md`](DESIGN.md)（玩法规范）互补。  
> **传输协议**：HTTPS + JSON（Godot `HTTPRequest`）  
> **明确不采用**：Netty 自定义协议、Protobuf、gRPC、MongoDB

---

## 一、技术选型（终版）

| 层级 | 选型 | 版本建议 | 说明 |
|------|------|----------|------|
| 语言 | Java | **17 LTS** | 与 Spring Boot 3 匹配 |
| 框架 | Spring Boot | **3.2+** | Web、Security、校验、定时任务 |
| ORM | MyBatis-Plus | 3.5+ | 复杂查询与 SQL 可控；交易行阶段更顺手 |
| 数据库 | MySQL | **8.0+** | 账号、角色、存档、经济、流水 |
| 缓存 | Redis | **7.x** | 排行榜、Token、限流、分布式锁 |
| 迁移 | Flyway | — | 数据库版本管理 |
| 文档 | springdoc-openapi | — | 自动生成 OpenAPI，Godot 侧对照 |
| 客户端 | Godot HTTPRequest | 4.6 | `Content-Type: application/json` |
| 部署 | Docker Compose | — | 单机起步：`api` + `mysql` + `redis` |

**不引入**：MongoDB、消息队列（MVP 阶段用 `@Scheduled` + Redis 即可）、微服务拆分。

---

## 二、总体架构

```text
┌──────────────────────────────────────────────────────────────┐
│  lost-miracle-client/ (Godot)                                 │
│  ApiClient (HTTPRequest)  ←→  LocalSaveProvider (现有逻辑)    │
│  AuthService / CloudSaveService / LeaderboardService ...      │
└────────────────────────────┬─────────────────────────────────┘
                             │ HTTPS / JSON
                             ▼
┌──────────────────────────────────────────────────────────────┐
│  Spring Boot 单体应用 (lost-miracle-api)                      │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌───────────┐ │
│  │ auth       │ │ character  │ │ save       │ │ leaderboard│ │
│  └────────────┘ └────────────┘ └────────────┘ └───────────┘ │
│  ┌────────────┐ ┌────────────┐ ┌────────────┐ (Phase 2+)     │
│  │ achievement│ │ mail       │ │ pvp-async  │                │
│  └────────────┘ └────────────┘ └────────────┘                │
└────────────┬───────────────────────────────┬─────────────────┘
             │                               │
             ▼                               ▼
        MySQL 8                          Redis 7
   (权威数据 + 存档 JSON)            (榜 / 会话 / 锁 / 限流)
```

**设计原则**

1. **单体优先**：一个 Spring Boot 进程承载全部 HTTP API，日活上万前不拆服务。
2. **MySQL 为唯一权威数据源**：Redis 只做缓存与排行榜，丢失可重建。
3. **存档 JSON 与客户端兼容**：服务端 `save_json` 字段结构与 `SaveManager._build_save_data()` 一致，减少双端维护。
4. **摘要字段冗余**：`level`、`power_score` 等写入独立列，排行榜不必解析整包 JSON。
5. **离线可玩**：网络失败时回退本地 `user://saves/`；联网后增量同步。

---

## 三、服务端工程结构

```text
lost-miracle-server/
  pom.xml
  src/main/java/com/lostmiracle/
    LostMiracleApplication.java
    common/
      ApiResponse.java          # 统一响应 { code, message, data }
      ErrorCode.java
      BusinessException.java
    config/
      SecurityConfig.java
      RedisConfig.java
      WebMvcConfig.java
    security/
      JwtTokenProvider.java
      JwtAuthFilter.java
    module/
      auth/
        AuthController.java
        AuthService.java
        dto/
      user/
        UserEntity.java
        UserMapper.java
      character/
        CharacterEntity.java
        CharacterService.java
      save/
        SaveController.java
        SaveService.java          # 上传/下载/冲突检测
        SaveSnapshotEntity.java
      leaderboard/
        LeaderboardController.java
        LeaderboardService.java   # 写 MySQL + 刷 Redis ZSET
      achievement/                # Phase 2
      mail/                       # Phase 2
      pvp/                        # Phase 3 异步切磋
  src/main/resources/
    application.yml
    db/migration/                 # Flyway
      V1__init.sql
      V2__leaderboard.sql
```

**依赖（`pom.xml` 核心）**

- `spring-boot-starter-web`
- `spring-boot-starter-security`
- `spring-boot-starter-validation`
- `mybatis-plus-boot-starter`
- `mysql-connector-j`
- `spring-boot-starter-data-redis`
- `jjwt-api` / `jjwt-impl`
- `flyway-core` + `flyway-mysql`
- `springdoc-openapi-starter-webmvc-ui`

---

## 四、统一 API 约定

### 4.1 基础

| 项 | 约定 |
|----|------|
| Base URL | `https://api.example.com/api/v1` |
| 编码 | UTF-8 JSON |
| 认证 | `Authorization: Bearer <access_token>`（登录接口除外） |
| 时间 | Unix 秒（`long`） |
| ID | 雪花或 UUID 字符串 |

### 4.2 统一响应

```json
{
  "code": 0,
  "message": "ok",
  "data": { }
}
```

| code | 含义 |
|------|------|
| 0 | 成功 |
| 40001 | 参数错误 |
| 40100 | 未登录 / Token 失效 |
| 40300 | 无权限 |
| 40901 | 存档版本冲突 |
| 42900 | 请求过于频繁 |
| 50000 | 服务器错误 |

### 4.3 分页

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "items": [],
    "page": 1,
    "page_size": 20,
    "total": 100
  }
}
```

---

## 五、核心数据模型（MySQL）

### 5.1 ER 关系（MVP）

```text
user (1) ──< (N) character
character (1) ── (1) character_save
character (1) ──< (N) leaderboard_entry (冗余快照，可选)
user (1) ──< (N) achievement_claim
character (1) ──< (N) mail
```

### 5.2 DDL 草案（Flyway V1）

```sql
-- 账号
CREATE TABLE `user` (
  `id`            BIGINT       NOT NULL PRIMARY KEY,
  `username`      VARCHAR(64)  NOT NULL UNIQUE,
  `password_hash` VARCHAR(255) NOT NULL,
  `status`        TINYINT      NOT NULL DEFAULT 1 COMMENT '1=正常 0=封禁',
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 角色（对应客户端一个 save 槽 / 一条 manifest 记录）
CREATE TABLE `character` (
  `id`                  BIGINT       NOT NULL PRIMARY KEY,
  `user_id`             BIGINT       NOT NULL,
  `name`                VARCHAR(32)  NOT NULL DEFAULT '冒险者',
  `player_class`        VARCHAR(16)  NOT NULL DEFAULT 'warrior',
  `level`               INT          NOT NULL DEFAULT 1,
  `power_score`         INT          NOT NULL DEFAULT 0 COMMENT '服务端计算的战力摘要',
  `current_dungeon_id`  VARCHAR(32)  NOT NULL DEFAULT 'bone_crypt',
  `last_login_at`       DATETIME     NULL,
  `created_at`          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_user_id` (`user_id`),
  CONSTRAINT `fk_character_user` FOREIGN KEY (`user_id`) REFERENCES `user` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 云存档（与客户端 save JSON 同构）
CREATE TABLE `character_save` (
  `character_id`   BIGINT       NOT NULL PRIMARY KEY,
  `save_version`   BIGINT       NOT NULL DEFAULT 1 COMMENT '乐观锁版本号',
  `save_json`      JSON         NOT NULL,
  `checksum`       CHAR(64)     NOT NULL COMMENT 'SHA-256 of canonical save_json',
  `client_updated_at` BIGINT     NOT NULL COMMENT '客户端上次修改时间(Unix秒)',
  `server_updated_at` DATETIME  NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  CONSTRAINT `fk_save_character` FOREIGN KEY (`character_id`) REFERENCES `character` (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 排行榜历史快照（可选，Redis 丢失时恢复）
CREATE TABLE `leaderboard_snapshot` (
  `id`           BIGINT      NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `board_type`   VARCHAR(32) NOT NULL COMMENT 'power / boss_kill / ...',
  `season`       VARCHAR(16) NOT NULL DEFAULT 'all',
  `character_id` BIGINT      NOT NULL,
  `score`        BIGINT      NOT NULL,
  `rank`         INT         NOT NULL,
  `snapshot_at`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_board_season` (`board_type`, `season`, `rank`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

### 5.3 存档 JSON 结构（与客户端对齐）

与 `SaveManager._build_save_data()` 保持一致：

```json
{
  "player": { "level", "exp", "gold", "class", "altar_buffs", "battle_roar_remaining", ... },
  "equipment": { "weapon", "helmet", "armor", "legs", "gloves", "ring_left", "ring_right", "necklace" },
  "inventory": [ /* 装备实例数组 */ ],
  "dungeon": { "normal_kill_count", "boss_respawn_at", ... },
  "world": { "current_dungeon_id", "auto_battle" }
}
```

服务端从 `save_json` 解析并刷新 `character.level`、`power_score`、`current_dungeon_id`。

**战力计算公式（服务端实现，与客户端展示可略有差异，以服务端为准上榜）：**

```text
power_score = f(level, 装备属性汇总, 强化等级, 套装件数)
```

初版可用简化公式：`level * 100 + sum(enhance_level) * 10 + inventory_count`，后续与 `PlayerData.get_final_stats()` 逻辑对齐或客户端上传 `power_score` 由服务端抽检。

---

## 六、Redis 设计

| Key 模式 | 类型 | TTL | 用途 |
|----------|------|-----|------|
| `auth:refresh:{userId}` | STRING | 7d | Refresh Token（可选） |
| `ratelimit:{userId}:{api}` | STRING | 1min | 接口限流 |
| `lb:{board}:{season}` | ZSET | — | 排行榜；member=`characterId`, score=`power` |
| `lb:meta:{board}:{season}` | HASH | — | 最后刷新时间、赛季信息 |
| `lock:save:{characterId}` | STRING | 10s | 存档上传分布式锁 |
| `lock:trade:{orderId}` | STRING | 30s | Phase 3 交易撮合 |

**排行榜读写**

```text
提交分数：ZADD lb:power:all <score> <characterId>
Top100：  ZREVRANGE lb:power:all 0 99 WITHSCORES
个人名次：ZREVRANK lb:power:all <characterId>
```

定时任务（每小时）：Redis ZSET → `leaderboard_snapshot` 落库。

---

## 七、API 设计（分阶段）

### Phase 1 — 账号 + 云存档 + 排行榜（MVP Online）

#### 7.1 注册 / 登录

`POST /auth/register`

```json
// Request
{ "username": "hero01", "password": "******" }

// Response data
{
  "access_token": "eyJ...",
  "expires_in": 7200,
  "user_id": 10001
}
```

`POST /auth/login` — 请求/响应同上。

`POST /auth/logout` — 请求头 `Authorization: Bearer <token>`；将 token 写入 Redis 黑名单（TTL = 剩余有效期），客户端登出/退出/关窗时调用。**每次启动客户端须重新登录**（JWT 不持久化到磁盘）。

`POST /auth/refresh` — Phase 1 可省略，Token 2h + 重新登录即可。

#### 7.2 角色列表 / 创建

`GET /characters`

```json
// Response data
{
  "items": [
    {
      "id": 20001,
      "name": "冒险者",
      "player_class": "warrior",
      "level": 12,
      "power_score": 1580,
      "current_dungeon_id": "corrupt_swamp",
      "last_login_at": 1749686400,
      "save_version": 45
    }
  ],
  "max_slots": 3
}
```

`POST /characters`

```json
// Request（可选）
{ "name": "新冒险者" }

// Response data：新建角色 + 初始 save（等同客户端 create_new_save）
```

#### 7.3 云存档 — 下载

`GET /characters/{characterId}/save`

```json
// Response data
{
  "character_id": 20001,
  "save_version": 45,
  "client_updated_at": 1749686400,
  "save": { /* 完整 save JSON，结构同本地 */ }
}
```

#### 7.4 云存档 — 上传

`PUT /characters/{characterId}/save`

```json
// Request
{
  "save_version": 45,
  "client_updated_at": 1749686500,
  "save": { /* 完整 save JSON */ }
}

// Response data（成功）
{
  "character_id": 20001,
  "save_version": 46,
  "server_updated_at": 1749686501,
  "power_score": 1620
}

// 冲突时 code=40901
{
  "code": 40901,
  "message": "save version conflict",
  "data": {
    "server_save_version": 46,
    "server_updated_at": 1749686400,
    "resolution": "choose_local_or_server"
  }
}
```

**冲突策略（客户端）：**

409 时自动下载云端存档覆盖本机，弹窗提示后强制重新登录（`CloudSaveService.handle_conflict`）。

#### 7.4.1 战斗结算 — settle

`POST /characters/{characterId}/dungeons/{dungeonId}/spawns/{slotId}/settle`

```json
// Request
{
  "saveVersion": 45,
  "monsterId": "rotting_skeleton"
}

// Response data：更新后的 save + 奖励摘要
{
  "saveVersion": 46,
  "exp": 120,
  "gold": 35,
  "items": [ /* ... */ ],
  "save": { /* 完整 save JSON */ }
}
```

服务端 `LootEngine` 权威掉落；客户端 `apply_server_save` 应用返回档（会话中的 `auto_battle` / 战吼计时由客户端保留）。

#### 7.5 排行榜

`GET /leaderboards/{boardType}?season=all&page=1&page_size=50`

`boardType`: `power` | `boss_kill` | `dungeon_level`（后续扩展）

```json
// Response data
{
  "board_type": "power",
  "season": "all",
  "my_rank": 128,
  "my_score": 1620,
  "items": [
    {
      "rank": 1,
      "character_id": 20088,
      "name": "冒险者",
      "player_class": "warrior",
      "level": 35,
      "score": 9850,
      "current_dungeon_id": "frozen_abyss"
    }
  ]
}
```

`POST /leaderboards/{boardType}/submit` — 一般由存档上传时服务端自动更新，也可独立上报：

```json
{ "character_id": 20001, "score": 1620, "extra": { "boss_kill_count": 12 } }
```

---

### Phase 2 — 成就 + 邮件

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/achievements` | 成就定义 + 个人进度 |
| POST | `/achievements/{id}/claim` | 领取奖励（写 `mail`） |
| GET | `/mail` | 邮件列表 |
| POST | `/mail/{id}/claim` | 领取附件到存档（服务端改 `save_json`） |

成就条件初版：服务端根据 `save_json` 解析校验（等级、金币、击杀数）；领奖通过 **邮件发放** 避免直接改客户端背包。

---

### Phase 3 — 异步 PvP + 交易行（预留）

| 方法 | 路径 | 说明 |
|------|------|------|
| PUT | `/pvp/defense` | 上传防守快照（属性摘要，非完整背包） |
| POST | `/pvp/challenge` | 发起挑战，返回防守快照 + 战斗种子 |
| POST | `/pvp/report` | 提交战斗结果，服务端抽查 / 更新 ELO |
| GET | `/leaderboards/pvp_elo` | 切磋榜 |

交易行需新增表：`item_registry`、`trade_listing`、`trade_order`，所有物品转移在 MySQL 事务内完成（见 §九）。

---

## 八、安全设计

| 项 | 方案 |
|----|------|
| 密码 | BCrypt 哈希，禁止明文 |
| Token | JWT HS256；`sub=userId`，`aud=game`，`exp=2h`；**登出黑名单**（Redis `auth:blacklist:*`，TTL=剩余有效期） |
| HTTPS | 生产环境强制 TLS |
| 限流 | Redis：`/save` 上传 10 次/分钟/角色；`/leaderboards/submit` 30 次/分钟 |
| 存档校验 | `checksum` = SHA-256(canonical JSON)；异常膨胀 > 512KB 拒绝 |
| 作弊 | 排行榜信任服务端计算的 `power_score`；异常涨幅告警（日志 + 人工） |
| CORS | 仅允许游戏启动器域名（Web 导出时） |

---

## 九、Phase 3 交易行数据模型（预留）

```sql
CREATE TABLE `item_registry` (
  `uid`           VARCHAR(64)  NOT NULL PRIMARY KEY,
  `character_id`  BIGINT       NOT NULL,
  `item_json`     JSON         NOT NULL,
  `bind_flag`     TINYINT      NOT NULL DEFAULT 0,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX `idx_owner` (`character_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `trade_listing` (
  `id`            BIGINT       NOT NULL PRIMARY KEY,
  `seller_id`     BIGINT       NOT NULL,
  `item_uid`      VARCHAR(64)  NOT NULL,
  `price`         INT          NOT NULL,
  `status`        TINYINT      NOT NULL DEFAULT 1 COMMENT '1=在售 2=已售 0=下架',
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY `uk_item_uid` (`item_uid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

成交流程：`Redis lock` → 校验 listing → 扣买家金币 / 转移 `item_registry` → 写 `trade_order` 流水 → 提交事务。

---

## 十、Godot 客户端改造设计

### 10.1 新增模块

```text
lost-miracle-client/scripts/
  network/
    ApiConfig.gd           # base_url, timeout
    ApiClient.gd           # HTTPRequest 封装：GET/POST/PUT + JSON + Token
    ApiResponse.gd         # 解析 { code, message, data }
    AuthService.gd
    CloudSaveService.gd
    LeaderboardService.gd
  autoload/
    NetworkManager.gd      # 可选 Autoload：登录态、联网开关
```

### 10.2 存档与同步

```text
SaveManager
  ├─ _build_save_data() / _apply_save_data()   # 内存序列化
  └─ CloudSaveService.upload / apply_server_save
```

**客户端 JWT**：仅内存；`NetworkManager.end_session()` 在登出/退出/关窗时调用 `POST /auth/logout` 并清理本地态。

**同步时机（联网时）：**

- 战斗胜利 → `settle` API（非 PUT save）  
- 强化 roll → 服务端 API 返回新档  
- 背包变更、切场景、登出、退出 → `sync_to_cloud`  
- 自动战斗进战前 → 跳过阻塞同步  

**流程：**

```text
登录 → 选择角色 → GET save
  ├─ 无云存档：上传本地或新建
  ├─ 有云存档且 version 更新：提示合并策略
  └─ 一致：直接进入游戏

游戏中：本地 save_game() 始终写盘；若已登录则异步 PUT save（失败入队列重试）
```

### 10.3 HTTPRequest 示例（伪代码）

```gdscript
func request(method: String, path: String, body: Dictionary = {}) -> Dictionary:
    var http := HTTPRequest.new()
    add_child(http)
    var headers := ["Content-Type: application/json"]
    if _token != "":
        headers.append("Authorization: Bearer %s" % _token)
    var err := http.request("%s%s" % [ApiConfig.BASE_URL, path], headers, method, JSON.stringify(body))
    # await completed, parse ApiResponse
```

---

## 十一、部署架构（开发 → 生产）

### 11.1 本地开发（Docker Compose）

```yaml
services:
  mysql:
    image: mysql:8.0
    environment:
      MYSQL_ROOT_PASSWORD: root
      MYSQL_DATABASE: lost_miracle
    ports: ["3306:3306"]
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
  api:
    build: ./lost-miracle-server
    ports: ["8080:8080"]
    environment:
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/lost_miracle
      SPRING_REDIS_HOST: redis
    depends_on: [mysql, redis]
```

Godot 开发配置：`ApiConfig.BASE_URL = "http://127.0.0.1:8080/api/v1"`

### 11.2 生产（单机起步）

```text
Nginx (TLS 终止) → Spring Boot :8080
                  → MySQL 主库
                  → Redis 单机/哨兵
```

日志：`logback` JSON 输出；后续可接 ELK。监控：Spring Actuator `/actuator/health`。

---

## 十二、实施路线图

| 阶段 | 周期 | 服务端交付 | 客户端交付 |
|------|------|------------|------------|
| **P0 基建** | 2 周 | 项目骨架、Flyway V1、注册登录 JWT | `ApiClient`、登录 UI 占位 |
| **P1 云存档** | 2 周 | 角色 CRUD、save 上下传、冲突检测 | `CloudSaveService`、进游戏拉档 |
| **P1 排行榜** | 1 周 | Redis ZSET + 查询 API | 地牢/主菜单排行榜页 |
| **P2 成就邮件** | 3 周 | 成就配置表、领取、邮件发放 | 成就页、邮箱 UI |
| **P3 异步 PvP** | 4 周 | 防守快照、ELO、结果上报 | 切磋入口、战报 |
| **P3 交易行** | 6 周+ | `item_registry`、挂单、撮合 | 交易 UI（最后做） |

---

## 十三、选型优劣总结

| 决策 | 优点 | 代价 / 风险 | 结论 |
|------|------|-------------|------|
| HTTP + JSON | Godot 原生支持；调试方便；与你 Java 栈 REST 成熟 | 体积略大于二进制；高频实时不如 WS | **MVP 最优** |
| Spring Boot | 事务、生态、你熟悉；快速出 API | 非实时对战网关 | **业务服首选** |
| MySQL | 存档 JSON + 关系数据一体；交易 ACID | 大 JSON 需注意 512KB 上限 | **唯一主库** |
| Redis | 排行榜性能极好 | 需设计持久化备份 | **强烈推荐** |
| 不用 MongoDB | 少一套运维；存档 JSON 列够用 | 极端大文档需 OSS | **MVP 正确** |
| 不用 Netty/Protobuf | 客户端零额外依赖 | 未来实时 PvP 再评估 WS | **现阶段正确** |

---

## 十四、版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-06-12 | 初版：HTTP+JSON、Spring Boot 3、MySQL、Redis；API 与表结构草案 |

---

*玩法与本地存档规范见 [`DESIGN.md`](DESIGN.md)。*

*Monorepo 布局：`lost-miracle-client/`（Godot）、`lost-miracle-server/`（Spring Boot，P1 API 已实现）。见根目录 [`README.md`](../README.md)。*
