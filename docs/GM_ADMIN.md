# GM 后台 — 架构与实施规划

> **版本** v1.0 | 2026-06-16  
> 与 [`DESIGN.md`](DESIGN.md)（玩法）、[`BACKEND_ARCHITECTURE.md`](BACKEND_ARCHITECTURE.md)（服务端）互补。

---

## 一、已确认决策

| 议题 | 决策 |
|------|------|
| **掉率生效方式** | 登录拉 **config bundle**；GM 发布后分钟级生效（客户端本地 JSON 作 fallback） |
| **部署形态** | 正式 **Web 管理台**（`lost-miracle-admin`），仅内网 / VPN 访问 |
| **改档粒度** | 允许改 **完整 save_json**（含背包装备）；**super** 角色 + **二次确认** |

---

## 二、目标能力

| 模块 | GM 操作 | 数据来源 |
|------|---------|----------|
| 玩家档案 | 搜索账号/角色、改档、封禁、删角 | `user` / `character` / `character_save` |
| 刷怪状态 | 查看全服槽位、重置 CD、释放占用 | `dungeon_spawn_slot` |
| 配置中心 | 掉率、探索概率、强化规则、刷怪常量 | `game_config` + Redis 缓存 |
| 运营 | 邮件、维护公告 | 现有 `mail` 模块 |
| 审计 | 所有写操作可追溯 | `gm_audit_log` |

**边界**：战斗结算仍客户端权威；config bundle 使 GM 改表对在线玩家生效，但不防本地改客户端作弊（服务端化掉落属 GM-P3 长期项）。

**实现状态（2026-06-16）**

- **GM-P0 已完成**：`/api/v1/admin/**` API、Flyway V7、默认 super 账号 bootstrap、审计日志
- **GM-P1 已完成**：`game_config` 发布 + `GET /api/v1/config/bundle` + 客户端 `ConfigService`
- **GM-P1 UI 已完成**：`lost-miracle-admin` Web 管理台

**默认 GM 账号**（首次启动自动创建，请立即改密）：

| 字段 | 默认值 |
|------|--------|
| 用户名 | `super` |
| 密码 | `gm-admin-change-me`（见 `application.yml` `lost-miracle.gm.bootstrap-super-password`） |

---

## 三、总体架构

```text
┌─────────────────────────┐       ┌─────────────────────────────────────────┐
│  lost-miracle-admin     │       │  lost-miracle-server                     │
│  Vite + React + AntD    │──────▶│  /api/v1/*           游戏 API（现有）   │
│  内网 / VPN 静态部署     │       │  /admin/api/v1/*     GM API（新增）      │
└─────────────────────────┘       │    auth / player / spawn / config / audit │
                                  └──────────────┬──────────────┬─────────────┘
                                                 ▼              ▼
                                            MySQL 8         Redis 7
                                       game_config         config:live
                                       gm_account           spawn / 榜
                                       gm_audit_log
```

> **实际路由前缀**：Spring `context-path=/api/v1`，GM API 为 `http://127.0.0.1:8080/api/v1/admin/...`（非 `/admin/api/v1`）。

**客户端新增**：登录成功后 `GET /api/v1/config/bundle?since={version}`，合并到 `DataManager` / `LootManager` 运行时配置。

---

## 四、权限模型

### 4.1 GM 账号（与玩家 `user` 表隔离）

```sql
-- V7__gm_admin.sql（草案）

CREATE TABLE gm_account (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  username      VARCHAR(64)  NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  role          VARCHAR(16)  NOT NULL DEFAULT 'operator',  -- viewer | operator | super
  status        TINYINT      NOT NULL DEFAULT 1,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE gm_audit_log (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  gm_account_id BIGINT       NOT NULL,
  action        VARCHAR(64)  NOT NULL,
  target_type   VARCHAR(32)  NOT NULL,
  target_id     VARCHAR(64)  NOT NULL,
  detail_json   JSON         NULL,
  ip            VARCHAR(45)  NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_audit_time (created_at),
  INDEX idx_audit_target (target_type, target_id)
);
```

### 4.2 角色权限

| 角色 | 读 | 写 |
|------|----|----|
| **viewer** | 玩家、存档、刷怪、配置、审计 | — |
| **operator** | 同上 | 改资源字段（金币/石头/等级）、重置刷怪、发邮件、**发布配置** |
| **super** | 同上 | operator 全部 + **完整 save_json**（二次确认）、封禁、删角、回滚配置、管理 GM 账号 |

JWT 区分 `aud=game` 与 `aud=admin`；`SecurityConfig` 对 `/admin/**` 使用独立 `AdminJwtAuthFilter`。

### 4.3 改档二次确认（super）

完整 `save_json` 替换流程：

1. `POST /admin/api/v1/characters/{id}/save/preview` — 提交新 JSON，返回 diff 摘要 + `confirm_token`（5 分钟有效）
2. `PUT /admin/api/v1/characters/{id}/save` — 请求体含 `confirm_token` + `reason`（必填，写入审计）
3. 服务端：`SaveValidator` 校验 → `save_version++` → 更新 `character` 摘要列 → 重算 `checksum` / `power_score` → 刷新排行榜 → 写 `gm_audit_log`（含改前改后 hash）

operator 仅可 PATCH 白名单字段（见 §5.1），不可提交完整 JSON。

---

## 五、API 设计

### 5.1 玩家档案

| 方法 | 路径 | 角色 | 说明 |
|------|------|------|------|
| GET | `/admin/api/v1/users?q=&page=` | viewer+ | 搜索账号 |
| GET | `/admin/api/v1/users/{userId}` | viewer+ | 账号详情含 `status` |
| POST | `/admin/api/v1/users/{userId}/ban` | super | `user.status = 0` |
| POST | `/admin/api/v1/users/{userId}/unban` | super | `user.status = 1` |
| GET | `/admin/api/v1/users/{userId}/characters` | viewer+ | 角色列表 |
| GET | `/admin/api/v1/characters/{id}/save` | viewer+ | 完整 save_json |
| PATCH | `/admin/api/v1/characters/{id}/save/fields` | operator+ | 白名单：`gold`, `level`, `exp`, `enhance_stone`, `forge_stone`, `frozen_stone`, `swamp_stone`, `health_potion` |
| POST | `/admin/api/v1/characters/{id}/save/preview` | super | 完整 JSON diff 预览 |
| PUT | `/admin/api/v1/characters/{id}/save` | super | 完整 JSON 替换（需 `confirm_token`） |
| DELETE | `/admin/api/v1/characters/{id}` | super | 复用 `CharacterService.delete` |

**复用现有逻辑**：`SaveService.upload(force=true)` 内核、`SaveValidator`、`PowerScoreCalculator`、`SaveChecksum`。

### 5.2 刷怪（已有 `dungeon_spawn_slot`）

| 方法 | 路径 | 角色 | 说明 |
|------|------|------|------|
| GET | `/admin/api/v1/dungeons/{dungeonId}/spawns` | viewer+ | 全槽状态 |
| POST | `/admin/api/v1/spawns/{slotId}/reset` | operator+ | 立即刷新 |
| POST | `/admin/api/v1/dungeons/{dungeonId}/spawns/reset-all` | operator+ | 整图重置 |

### 5.3 配置中心（config bundle）

**表结构**

```sql
CREATE TABLE game_config (
  config_key    VARCHAR(64)  NOT NULL PRIMARY KEY,
  json_value    JSON         NOT NULL,
  description   VARCHAR(255) NULL,
  updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE game_config_publish (
  id            BIGINT PRIMARY KEY AUTO_INCREMENT,
  version       BIGINT       NOT NULL UNIQUE,
  published_by  BIGINT       NOT NULL,
  note          VARCHAR(255) NULL,
  snapshot_json JSON         NOT NULL COMMENT '发布时全量 config_key -> value',
  published_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**游戏侧 API**

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/v1/config/bundle` | 返回 `{ version, configs: { key: value } }` |
| GET | `/api/v1/config/bundle?since={v}` | `since >= 当前 version` 时返回 304 / 空 |

**GM 侧 API**

| 方法 | 路径 | 角色 | 说明 |
|------|------|------|------|
| GET | `/admin/api/v1/config` | viewer+ | 当前线上配置 + version |
| PUT | `/admin/api/v1/config/{key}` | operator+ | 保存草稿（未发布） |
| POST | `/admin/api/v1/config/publish` | operator+ | 发布 → version++，写 Redis `config:live`，失效缓存 |
| GET | `/admin/api/v1/config/history` | viewer+ | 发布历史 |
| POST | `/admin/api/v1/config/rollback/{publishId}` | super | 回滚到某次发布 |

**首批 config_key**（从客户端/服务端现有常量迁移）

| config_key | 说明 | 现位置 |
|------------|------|--------|
| `loot.equip_drop` | 装备掉率 | `LootManager.gd` `EQUIP_DROP` |
| `loot.gold_drop` | 金币区间 | `LootManager.gd` `GOLD_DROP` |
| `loot.stone_drop` | 强化石 | `LootManager.gd` `STONE_DROP` |
| `dungeon.explore_weights` | 探索 75/10/10/5 | `dungeon_events.json` |
| `enhance.rules` | 强化成功率 | `enhance_rules.json` |
| `spawn.constants` | 槽位数 / CD | `SpawnConstants.java` |

**客户端接入**

```text
LoginScene 登录成功
  → ConfigService.fetch_bundle()
  → 若 version > 本地缓存：合并 configs
  → LootManager / DataManager 读运行时 overlay（bundle 优先，本地 JSON fallback）
```

建议本地缓存 `user://config_bundle.json` + `config_version`，每次进主界面轻量 `since` 检查。

### 5.4 GM 认证

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/admin/api/v1/auth/login` | 返回 admin JWT |
| GET | `/admin/api/v1/auth/me` | 当前 GM 信息与 role |

---

## 六、Web 管理台（lost-miracle-admin）

### 6.1 技术栈

| 项 | 选型 |
|----|------|
| 框架 | Vite 5 + React 18 + TypeScript |
| UI | Ant Design 5 |
| 路由 | React Router 6 |
| HTTP | axios（拦截器注入 admin JWT） |
| 构建 | 静态产物 `dist/`，Nginx 托管 |

### 6.2 页面结构

```text
/login
/dashboard                    # 在线估算、今日注册、当前 config version
/players
  /search                     # 账号搜索
  /users/:id                  # 账号详情、封禁
  /characters/:id             # 存档详情
      Tab: 常用字段 (operator)
      Tab: JSON 编辑器 (super, 保存前弹二次确认)
/world/spawns                 # 四地图刷怪槽表格 + 重置
/config
  /loot                       # 掉率表单（映射 loot.* keys）
  /dungeon                    # 探索权重
  /enhance                    # 强化规则
  /history                    # 发布记录、回滚 (super)
/ops/mail                     # 发邮件（P2）
/system
  /gm-accounts                # super
  /audit-log                  # 操作审计
```

### 6.3 部署

```text
# docker-compose 扩展示意
services:
  api:          # 现有 Spring Boot，暴露 8080（内网）
  admin-web:    # nginx:alpine，挂载 lost-miracle-admin/dist
                # 仅 bind 10.x / docker internal network
                # 生产：VPN 或 Cloudflare Access / IP 白名单
```

环境变量：

- `VITE_API_BASE=http://api:8080/admin/api/v1`（构建时注入）

CORS：`WebMvcConfig` 允许 admin 前端 origin（仅内网域名）。

---

## 七、安全

1. **网络隔离**：GM 前端与 `/admin/**` 不对公网开放
2. **双 JWT**：游戏 token 不能访问 admin 路由
3. **审计**：所有写操作记录 `gm_account_id`、IP、`detail_json`（super 改档存改前/改后 checksum）
4. **限流**：admin 写接口单独 bucket（如 30/min/IP）
5. **密码**：GM 账号 bcrypt；super 建议后续加 TOTP（P2）

---

## 八、实施路线图

| 阶段 | 周期 | 交付物 |
|------|------|--------|
| **GM-P0** | 1~2 周 | Flyway V7（gm 表）、Admin JWT、`module/admin`、玩家查档/改档/封禁、刷怪重置、审计 |
| **GM-P1** | 2 周 | `game_config` + 发布 API + Redis 缓存；客户端 `ConfigService` + `LootManager` overlay |
| **GM-P1 UI** | 1~2 周 | `lost-miracle-admin`：登录、玩家、刷怪、配置 JSON 编辑与发布 |
| **GM-P2** | 2 周 | 掉率表单化、邮件群发、维护开关、配置回滚 UI |
| **GM-P3** | 长期 | 战斗结算服务端化，掉落防作弊 |

### P0 服务端目录（新增）

```text
module/admin/
  AdminAuthController.java
  AdminAuthService.java
  AdminPlayerController.java
  AdminPlayerService.java      # 封装 SaveService.forceUpload + 审计
  AdminSpawnController.java
  GmAuditService.java
  entity/GmAccountEntity.java
  entity/GmAuditLogEntity.java
  security/AdminJwtAuthFilter.java
  security/AdminJwtTokenProvider.java
  dto/...
```

### P1 客户端目录（新增）

```text
scripts/network/ConfigService.gd   # Autoload，fetch bundle
scripts/autoload/DataManager.gd    # get_runtime_config(key, fallback)
scripts/item/LootManager.gd        # 读 overlay 替代硬编码 const
```

---

## 九、与现有代码衔接

| 已有 | GM 用法 |
|------|---------|
| `SaveValidator` | GM 改档必经校验 |
| `SaveService.upload(..., force)` | GM 强制写档 |
| `CharacterService.delete` | GM 删角 |
| `SpawnService` / `DungeonSpawnMapper` | GM 重置槽位 |
| `user.status` | GM 封禁 |
| `EnhanceRulesLoader` | 迁移到 `game_config.enhance.rules` |

---

## 十、验收标准

**GM-P0**

- [x] GM 登录获取 admin JWT；游戏 JWT 访问 `/admin/**` 返回 403
- [x] viewer 可查玩家存档；operator 可改金币；super 可完整替换 save_json（需二次确认）
- [x] 改档后客户端下次同步或重新登录拿到新数据
- [x] 刷怪重置后 `GET .../spawns` 可见 CD 清零
- [x] 所有写操作可在审计页查到

**GM-P1**

- [x] GM 发布 config 后 version 递增
- [x] 客户端登录拉 bundle，掉率按新配置生效（无需发版）
- [x] 无 bundle 时使用本地 JSON fallback

**GM-P1 UI**

- [x] 内网可访问管理台并完成 P0/P1 全部操作
- [x] super 改 JSON 前有 diff 预览与确认对话框
