# MoonSim Actors 开发视图

开发视图描述代码组织、构建、测试、发布和协作方式。

## 仓库组织

建议采用单仓库多包或单包多模块结构，第一阶段以简单为主：

```text
moonsim-actors/
  moon.mod.json
  types.mbt
  runtime.mbt
  demo.mbt
  moonsim_wbtest.mbt
  cmd/
  examples/
  bench/
  docs/
  README.md
  LICENSE
```

后续如 CLI 和 library 边界变大，再拆分：

```text
packages/
  moonsim-core/
  moonsim-actors/
  moonsim-cli/
```

## 开发里程碑

| 阶段 | 目标 | 产出 |
| --- | --- | --- |
| M0 | 项目脚手架和文档 | README、架构文档、API 草案、申报书 |
| M1 | 最小 Actor 框架 | actor、mailbox、tell、基础测试 |
| M2 | Ask/Timeout/Supervisor | ask、虚拟时间 timeout、Stop/Restart 策略 |
| M3 | 确定性调度 | seed、scheduler、trace log、replay 雏形 |
| M4 | 故障注入 | delay、drop、reorder、pause/resume |
| M5 | 示例和 CLI | KV cluster demo、CLI run/replay |
| M6 | Benchmark 和发布 | benchmark 报告、文档、mooncakes 发布 |

## 测试策略

- 单元测试：mailbox、scheduler、virtual clock、fault model。
- 异步测试：actor ask/tell、timeout、supervisor。
- 确定性测试：相同 seed 产生相同事件序列。
- 性质测试雏形：多 seed 跑同一个 invariant。
- 示例测试：KV cluster demo 的一致性约束。
- CLI smoke test：运行 demo 并检查退出码和摘要输出。

## 文档策略

必须文档：

- README：项目定位、快速开始、示例、限制。
- API Sketch：核心 API 和设计原因。
- 4+1 视图：场景、逻辑、开发、进程、物理。
- Project Proposal：比赛申报书一页版。
- Examples Guide：如何运行示例和 replay。
- Benchmark Report：性能数据和解释。

## 代码风格原则

- 核心路径优先小而稳定，避免过早抽象。
- 错误类型要可展示，不只返回字符串。
- trace 输出要面向调试，字段名称稳定。
- 示例代码要比框架内部代码更易读。
- 每个模块都要有最小测试，不依赖真实时间。

## 后续待决策

- 最终项目名：`MoonSim Actors`、`mbt-sim-actors`、`moonsim` 三选一。
- 第一示例：KV cluster 还是 task queue。
- CLI 是否单独作为 package。
- trace 格式使用 JSON 还是自定义文本加 JSON 导出。
- supervisor 第一阶段是否只支持 `Stop` / `Restart`。
- benchmark 指标：吞吐、虚拟时间步数、事件数量、trace 大小。
