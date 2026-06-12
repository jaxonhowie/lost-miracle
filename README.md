# 失落奇迹：亡灵地牢 (Lost Miracle)

Monorepo 结构：

```text
lost-miracle/
├── lost-miracle-client/   Godot 4.6 客户端（用 Godot 打开此目录）
├── lost-miracle-server/   Spring Boot 3 服务端（HTTP + JSON）
├── docs/                  设计文档
│   ├── DESIGN.md          玩法规范
│   └── BACKEND_ARCHITECTURE.md
└── CLAUDE.md              AI 协作速查
```

## 快速开始

### 客户端

```bash
# Godot 4.6.2 → Import → 选择 lost-miracle-client/project.godot
```

详见 [`lost-miracle-client/README.md`](lost-miracle-client/README.md)。

### 服务端

```bash
cd lost-miracle-server
docker compose up -d
export JAVA_HOME=$(/usr/libexec/java_home -v 17)   # macOS
mvn spring-boot:run
```

详见 [`lost-miracle-server/README.md`](lost-miracle-server/README.md)。
