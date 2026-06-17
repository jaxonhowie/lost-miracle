# DevLoop — 自主开发任务队列

> 状态: ⬜ 待办 | 🔄 进行中 | ✅ 完成 | ❌ 需人工 | ⏭️ 跳过

## Sprint 1 — 恢复服务端测试基础设施

| # | 任务 | 状态 | 验证 Gate | 备注 |
|---|---|---|---|---|
| 1.1 | 恢复 IntegrationTestBase/Config + schema + yml | ✅ | `mvn compile -q` | 已在 master，无需 cherry-pick |
| 1.2 | 恢复 9 个核心集成测试文件 | ✅ | `mvn test` | 17 files, 26→31 tests |
| 1.3 | 修复测试编译/运行错误 | ✅ | `mvn test` 全绿 | 无需修复，全部通过 |

## Sprint 2 — CI Pipeline

| # | 任务 | 状态 | 验证 Gate | 备注 |
|---|---|---|---|---|
| 2.1 | 创建 `.github/workflows/ci.yml` | ✅ | YAML 语法校验 | Server + Admin + Client 三 job |
| 2.2 | Admin 添加 ESLint | ✅ | `npm run build` + `npm run lint` | flat config, 修复 1 个 lint error |

## Sprint 3 — 安全 P0

| # | 任务 | 状态 | 验证 Gate | 备注 |
|---|---|---|---|---|
| 3.1 | JWT 密钥外部化 + 玩家/管理员分离 | ✅ | `mvn test` | 环境变量 + admin 独立密钥 |
| 3.2 | SaveValidator 强化 + 移除 force | ✅ | `mvn test` | 物品 id/enhance_level/slot 校验 |
| 3.3 | 登录防暴破 + 用户名枚举修复 | ✅ | `mvn test` | IP 限速 10/min + 模糊错误消息 |

## Sprint 4 — 客户端健壮性

| # | 任务 | 状态 | 验证 Gate | 备注 |
|---|---|---|---|---|
| 4.1 | CloudSaveService 存档队列持久化 | ✅ | 代码审查 | user://pending_syncs.json |
| 4.2 | 错误 UI 反馈 (DataManager/BattleManager) | ✅ | 代码审查 | 信号 + 弹窗替代静默 |
| 4.3 | 场景路径常量化 | ✅ | grep 零残留 | ScenePaths.gd + 21 处替换 |

---

## 进度统计

- 总任务: 11
- 完成: **11**
- 进行中: 0
- 待办: 0
- 当前 Sprint: **全部完成** ✅
- 启动时间: 2026-06-17
- 完成时间: 2026-06-17

## 提交记录

```
eb76a03 client: 场景路径常量化，消除全部硬编码
171db6b client: 错误 UI 反馈替代静默失败
2d9040f client: 存档队列持久化到 user://pending_syncs.json
49cb305 security: 登录防暴破 + 修复用户名枚举
acaa43c security: SaveValidator 强化 + 移除客户端 force 绕过
7f14487 security: JWT 密钥外部化 + admin/player 分离
685af4b admin: 添加 ESLint 配置并修复 lint 错误
b8893d7 ci: 添加 GitHub Actions CI pipeline
```
