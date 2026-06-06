# OSC2026 申报草稿

## 项目名称

MoonSim Actors

## 项目定位

MoonSim Actors 是一个面向 MoonBit 的轻量 Actor 框架与确定性模拟测试工具，用于帮助后端和系统组件开发者复现并测试异步并发场景。

## 背景问题

后端系统中的并发问题常常来自消息乱序、延迟、超时、节点暂停、状态复制不一致和故障恢复。真实环境中复现这些问题成本高，传统单元测试也难以稳定覆盖时序问题。MoonSim Actors 通过单进程确定性事件循环和 seed 驱动调度，让开发者能用较低成本构造可重复的并发模拟场景。

## 当前能力

- Actor mailbox、`tell`、`ask/reply`。
- 虚拟时间 timeout，不依赖真实 sleep。
- seed 驱动确定性调度和 `Reorder` 乱序复现。
- `DelayEvery`、`DropEvery`、`pause/resume_actor` 故障注入。
- 内置 `Echo`、`KvLeader`、`KvFollower` actor。
- `Scripted` actor，通过 `HandlerRule` 配置自定义 receive 行为。
- `TypedActorRef[T]`，支持业务类型消息通过 encoder 进入 runtime。
- supervisor tree，支持父子关系、级联 stop/restart、restart limit。
- trace archive、trace JSON、trace 文件读写和 replay 校验。
- CLI 支持 run、bench、trace、replay。
- benchmark 输出 text、Markdown、JSON，并记录真实 elapsed_us。

## 创新点

- 面向 MoonBit 生态的 deterministic actor simulation。
- 把并发测试关注点收敛为 seed、fault rule、virtual time 和 trace。
- 用数据驱动 scripted handler 降低用户写模拟服务的门槛。
- 同时提供库 API、CLI、示例服务和 benchmark 工具，便于比赛演示。

## 演示命令

```powershell
moon run cmd/moonsim -- run kv_cluster --seed 42
moon run cmd/moonsim -- bench mailbox --messages 1000 --format markdown
moon run cmd/moonsim -- trace kv_cluster --seed 42 --out tmp_trace.json --format json
moon run cmd/moonsim -- replay file tmp_trace.json --format json
```

## 后续规划

- 更完整的 actor trait 和用户自定义 receive 函数。
- 概率故障、网络分区和多故障组合。
- 更严格的 replay 内容校验和 trace viewer。
- 面向真实后端服务测试的场景模板。
