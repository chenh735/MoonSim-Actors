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

当前仓库已经包含第一版 MoonSim Actors 的最小实现：

- 根包核心库：`ActorRef`、`SimRuntime`、mailbox、虚拟时间、trace、故障规则。
- CLI demo：`cmd/moonsim`。
- KV cluster 风格示例：`examples/kv_cluster`。
- mailbox benchmark 示例：`bench/mailbox`。
- 白盒测试：`moonsim_wbtest.mbt`。

## 快速开始

安装 MoonBit 工具链后，可以运行：

```text
moon test
moon run cmd/moonsim
moon run examples/kv_cluster
moon run bench/mailbox
```

## 第一版 API

第一版先采用 `String` 作为消息载荷，重点验证 actor mailbox、确定性调度、虚拟时间、故障注入和 trace 这几个核心机制。

```moonbit
let sim = SimRuntime::new(42)
let worker = sim.spawn("worker")
worker.tell(sim, "hello")
let result = worker.ask(sim, "ping", 10)
sim.run_all(64)
println(sim.trace_text())
```

后续可以在这个基础上把消息载荷泛型化，并引入真正的 actor handler / receive 抽象。
