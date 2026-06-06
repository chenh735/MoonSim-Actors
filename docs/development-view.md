# MoonSim Actors 开发视图

开发视图描述当前代码组织、测试策略、验证命令和协作方式。

## 仓库组织

```text
moonsim-actors/
  moon.mod
  moon.pkg
  LICENSE
  README.md
  types.mbt
  runtime.mbt
  demo.mbt
  cli.mbt
  *_wbtest.mbt
  cmd/moonsim/
  examples/kv_cluster/
  bench/mailbox/
  docs/
```

## 模块职责

- `types.mbt`：领域类型、actor 状态、handler rule、trace format、benchmark summary。
- `runtime.mbt`：事件调度、故障注入、ask/reply、监督树、scripted handler、trace/replay/file I/O。
- `demo.mbt`：KV 场景、trace 场景导出、benchmark 执行与报告渲染。
- `cli.mbt`：CLI 参数解析与命令分发。
- `cmd/moonsim`：真实命令行入口，只读取 `@env.args()` 并打印报告。

## 测试策略

| 测试文件 | 覆盖范围 |
| --- | --- |
| `moonsim_wbtest.mbt` | 低层 runtime 兼容行为、fault、restart |
| `actor_handlers_wbtest.mbt` | Echo/KV handler、ask/reply、KV 状态 |
| `typed_scripted_wbtest.mbt` | 类型化消息、scripted receive rules |
| `supervisor_tree_wbtest.mbt` | 父子 actor、级联 stop、restart limit |
| `replay_wbtest.mbt` | trace archive replay |
| `trace_file_wbtest.mbt` | trace JSON、文件读写、文件 replay |
| `cli_wbtest.mbt` | CLI run/bench/replay smoke |
| `benchmark_reports_wbtest.mbt` | benchmark text/Markdown/JSON、CLI trace file |

## 当前验证

```powershell
moon check
moon test
moon run cmd/moonsim -- run kv_cluster --seed 9
moon run cmd/moonsim -- bench mailbox --messages 5 --format json
moon run cmd/moonsim -- trace kv_cluster --seed 9 --out tmp_cli_trace.json --format json
moon run cmd/moonsim -- replay file tmp_cli_trace.json --format json
```

当前测试数量：24 个。

## 代码风格原则

- 新关键函数使用简短 `///|` 注释说明职责。
- 保持核心状态内聚在 `SimRuntime`，避免 CLI 或 demo 直接改 actor cell。
- 自定义行为用 `HandlerRule` 表达，避免过早引入复杂 trait 对象。
- 文件 I/O 仅在 trace 边界出现，依赖 `moonbitlang/x/fs`。
- benchmark 测量和报告渲染放在 `demo.mbt`，CLI 只选择格式。
