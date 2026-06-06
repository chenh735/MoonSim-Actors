# MoonSim Actors

MoonSim Actors 是一个面向 MoonBit 的轻量 Actor 框架与确定性模拟测试工具，用于模拟后端服务里的并发、乱序、延迟、超时、故障恢复和状态复制问题。

项目定位：给后端和系统组件提供一个可复现的单进程并发实验台。你可以用 seed 固定调度顺序，用 fault rule 注入延迟/丢包/乱序，用 trace 文件记录和 replay 场景。

## 当前能力

- Actor 引用与 mailbox：`ActorRef.tell`、`ActorRef.ask`、`take_mailbox`。
- 类型化消息入口：`TypedActorRef[T]` 通过 encoder 发送业务 enum/struct。
- 内置 actor：`Sink`、`Echo`、`KvLeader`、`KvFollower`。
- 自定义 actor：`Scripted` + `HandlerRule` 配置 receive 行为。
- ask/reply：handler 生成 reply，或虚拟 timeout 返回错误。
- 虚拟时间：timeout 与延迟不依赖真实 sleep。
- 确定性调度：默认按虚拟时间和序号调度，`Reorder` 使用 seed 复现乱序。
- 故障注入：`DelayEvery`、`DropEvery`、`Reorder`、`pause/resume_actor`。
- supervisor tree：父子 actor、级联 stop/restart、restart limit。
- trace/replay：文本 archive、JSON、文件读写和 replay 校验。
- KV cluster demo：leader/follower 使用真实 KV 状态，展示复制前后读取差异。
- CLI：`run`、`bench`、`trace`、`replay`。
- benchmark：真实 elapsed_us、虚拟时间、delivered、trace events，支持 text/Markdown/JSON。

## 快速开始

如果当前 PowerShell 还没重启，可以直接使用完整路径：

```powershell
cd C:\Users\chenhao\Desktop\codex
& $HOME\.moon\bin\moon.exe check
& $HOME\.moon\bin\moon.exe test
```

如果 `moon` 已经在 PATH 中：

```powershell
moon check
moon test
moon run cmd/moonsim -- run kv_cluster --seed 42
moon run cmd/moonsim -- bench mailbox --messages 1000 --format json
moon run cmd/moonsim -- trace kv_cluster --seed 42 --out tmp_trace.json --format json
moon run cmd/moonsim -- replay file tmp_trace.json --format json
```

也可以运行示例包：

```powershell
moon run examples/kv_cluster
moon run bench/mailbox
```

## API 示例

```moonbit
let sim = SimRuntime::new(42)
let cache = sim.spawn_scripted_actor("cache", [
  HandlerRule::{ matcher: MatchPrefix("set "), action: PutFromParts(1, 2) },
  HandlerRule::{ matcher: MatchPrefix("get "), action: GetFromParts(1) },
])
cache.tell(sim, "set token abc")
sim.run_all(16)
let result = cache.ask(sim, "get token", 10)
println(ask_result_text(result))
println(sim.trace_json())
```

## 代码结构

```text
types.mbt                    核心领域类型
runtime.mbt                  确定性运行时、调度、handler、supervisor、trace/replay
demo.mbt                     KV demo、benchmark、trace 场景导出
cli.mbt                      CLI 参数解析与命令分发
*_wbtest.mbt                 白盒和 smoke 测试
cmd/moonsim                  CLI 入口
examples/kv_cluster          KV 示例入口
bench/mailbox                mailbox benchmark 入口
docs/                        架构视图、TODO、发布说明、申报草稿
LICENSE                      Apache-2.0
```

## 文档

- [TODO 完成记录](docs/todo.md)
- [场景视图](docs/scenarios-view.md)
- [逻辑视图](docs/logical-view.md)
- [开发视图](docs/development-view.md)
- [进程视图](docs/process-view.md)
- [物理视图](docs/physical-view.md)
- [Mooncakes 发布准备](docs/mooncakes-publish.md)
- [OSC2026 申报草稿](docs/osc2026-submission.md)

## 验证状态

当前验证命令：

```text
moon check
moon test
moon run cmd/moonsim -- run kv_cluster --seed 9
moon run cmd/moonsim -- bench mailbox --messages 5 --format json
moon run cmd/moonsim -- trace kv_cluster --seed 9 --out tmp_cli_trace.json --format json
moon run cmd/moonsim -- replay file tmp_cli_trace.json --format json
moon run examples/kv_cluster
moon run bench/mailbox
```

测试数量：24 个，全部通过。
