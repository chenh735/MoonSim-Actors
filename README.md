# MoonSim Actors

MoonSim Actors 是一个面向 MoonBit 的轻量 Actor 框架与确定性模拟测试工具，计划用于参加 MoonBit 国产基础软件生态开源大赛。

项目目标是帮助开发者复现和测试异步后端系统中的消息乱序、延迟、超时、故障恢复和调度问题。第一阶段优先支持 MoonBit native backend。

## 项目定位

MoonSim Actors 不只是 Actor 封装。它会把以下能力放进一个可测试、可展示、可发布的工程里：

- Actor 编程模型。
- 确定性调度器。
- 虚拟时间。
- 故障注入。
- 可重放 trace log。
- CLI、示例服务和 benchmark。

## MVP 范围

第一版计划完成：

- `ActorRef.tell`
- `ActorRef.ask` with timeout
- mailbox
- actor spawn/stop
- virtual clock
- deterministic scheduler with seed
- trace log
- delay/drop/reorder fault model
- KV cluster 或 task queue 示例
- CLI run/replay 基础能力
- benchmark 基础报告

## 文档

4+1 架构视图已经拆分为五个独立文档：

- [场景视图](docs/scenarios-view.md)
- [逻辑视图](docs/logical-view.md)
- [开发视图](docs/development-view.md)
- [进程视图](docs/process-view.md)
- [物理视图](docs/physical-view.md)

## 初步里程碑

| 阶段 | 目标 |
| --- | --- |
| M0 | 项目脚手架、README、架构文档、申报材料 |
| M1 | 最小 Actor 框架 |
| M2 | Ask、Timeout、Supervisor |
| M3 | 确定性调度与 trace |
| M4 | 故障注入 |
| M5 | 示例服务和 CLI |
| M6 | Benchmark、文档完善、mooncakes 发布 |

## 当前状态

当前仓库处于架构设计阶段，下一步建议补充：

- `docs/project-proposal.md`：比赛申报书一页版。
- `docs/api-sketch.md`：核心 API 草案。
- MoonBit 项目脚手架。

