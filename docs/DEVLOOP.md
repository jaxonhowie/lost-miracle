# DevLoop — 自主开发任务队列

> 自动生成，由 ZCode 自主推进循环驱动。
> 状态: ⬜ 待办 | 🔄 进行中 | ✅ 完成 | ❌ 需人工 | ⏭️ 跳过

## Sprint 1 — 恢复服务端测试基础设施

| # | 任务 | 状态 | 验证 Gate | 备注 |
|---|---|---|---|---|
| 1.1 | 恢复 IntegrationTestBase/Config + schema + yml | ⬜ | `mvn compile -q` | 从 git 历史 cherry-pick |
| 1.2 | 恢复 9 个核心集成测试文件 | ⬜ | `mvn test` | 需适配已删除的 LootEngine 等 |
| 1.3 | 修复测试编译/运行错误 | ⬜ | `mvn test` 全绿 | 裁剪引用已删除类的过时测试 |

## Sprint 2 — CI Pipeline

| # | 任务 | 状态 | 验证 Gate | 备注 |
|---|---|---|---|---|
| 2.1 | 创建 `.github/workflows/ci.yml` | ⬜ | YAML 语法校验 | Server: mvn test, Admin: npm run build |
| 2.2 | Admin 添加 ESLint | ⬜ | `npm run build` + `npm run lint` | flat config |

## Sprint 3 — 安全 P0

| # | 任务 | 状态 | 验证 Gate | 备注 |
|---|---|---|---|---|
| 3.1 | JWT 密钥外部化 + 玩家/管理员分离 | ⬜ | `mvn compile` + `mvn test` | 环境变量替代硬编码 |
| 3.2 | SaveValidator 强化 + 移除 force | ⬜ | `mvn test` | 物品白名单 + enhance_level 上限 |
| 3.3 | 登录防暴破 | ⬜ | `mvn test` | RateLimitService.checkLogin |

## Sprint 4 — 客户端健壮性

| # | 任务 | 状态 | 验证 Gate | 备注 |
|---|---|---|---|---|
| 4.1 | CloudSaveService 存档队列持久化 | ⬜ | 代码审查 | user://pending_syncs.json |
| 4.2 | 错误 UI 反馈 (DataManager/BattleManager) | ⬜ | 代码审查 | 弹窗替代静默 |
| 4.3 | 场景路径常量化 | ⬜ | grep 无硬编码路径 | preload 替代字符串 |

---

## 进度统计

- 总任务: 11
- 完成: 0
- 进行中: 0
- 待办: 11
- 当前 Sprint: 1
- 启动时间: 2026-06-17
