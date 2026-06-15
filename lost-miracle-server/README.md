# Lost Miracle Server

失落奇迹：亡灵地牢 — HTTP + JSON 服务端（Spring Boot 3 / JDK 17）。

Monorepo 根目录：[`../README.md`](../README.md)  
设计文档：[`../docs/BACKEND_ARCHITECTURE.md`](../docs/BACKEND_ARCHITECTURE.md)  
Godot 客户端：[`../lost-miracle-client/`](../lost-miracle-client/README.md)

## 环境要求

- **JDK 17+**（Spring Boot 3 必须；macOS 可 `export JAVA_HOME=$(/usr/libexec/java_home -v 17)`）
- Maven 3.6+
- Docker（用于 MySQL / Redis）

## 快速启动

```bash
# 1. 启动依赖
docker compose up -d

# 2. 启动 API
mvn spring-boot:run
```

- API Base：`http://127.0.0.1:8080/api/v1`
- Swagger UI：`http://127.0.0.1:8080/api/v1/swagger-ui.html`
- Health：`http://127.0.0.1:8080/api/v1/actuator/health`

## 已实现 API（P1）

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/auth/register` | 注册 |
| POST | `/auth/login` | 登录 |
| GET | `/characters` | 角色列表 |
| POST | `/characters` | 创建角色 |
| GET | `/characters/{id}/save` | 下载云存档 |
| PUT | `/characters/{id}/save` | 上传云存档 |
| GET | `/leaderboards/power` | 战力榜 |
| POST | `/characters/{id}/enhance/roll` | 服务端权威强化（需 `saveVersion`） |
| GET | `/characters/{id}/mail` | 邮件列表 |
| POST | `/characters/{id}/mail/{mailId}/claim` | 领取邮件（需 `saveVersion`） |
| GET | `/achievements?characterId=` | 成就进度 |
| POST | `/achievements/{id}/claim?characterId=` | 领取成就奖励（需 `saveVersion`） |

## 示例

```bash
# 注册
curl -s -X POST http://127.0.0.1:8080/api/v1/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"hero01","password":"123456"}'

# 登录（记下 accessToken）
curl -s -X POST http://127.0.0.1:8080/api/v1/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"hero01","password":"123456"}'

# 创建角色
curl -s -X POST http://127.0.0.1:8080/api/v1/characters \
  -H "Authorization: Bearer <token>" \
  -H 'Content-Type: application/json' \
  -d '{}'
```

## 配置

`src/main/resources/application.yml`：

- MySQL：`jdbc:mysql://127.0.0.1:3306/lost_miracle`（用户/密码 `root`/`root`）
- Redis：`127.0.0.1:6379`
- JWT Secret：生产环境务必修改 `lost-miracle.jwt.secret`（≥32 字符）
