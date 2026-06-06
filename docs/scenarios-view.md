# MoonSim Actors 场景视图

场景视图描述系统为什么存在，以及当前实现如何被用户实际使用。

## 场景 A：模拟 KV cluster

```powershell
moon run cmd/moonsim -- run kv_cluster --seed 42
```

系统会创建 `KvLeader` 和 `KvFollower`，执行 `put`、`replicate` 和读请求。输出包含 summary、ask 结果和 trace。

验收点：

- leader/follower 都能读到复制后的值。
- 复制前读取 follower 得到 `missing`，复制后得到 `value`。
- trace 包含 `ActorHandled` 和 `MessageReplied`。

## 场景 B：自定义后端模拟服务

用户可以用 `HandlerRule` 配置一个 actor，让它模拟缓存、队列、RPC mock 或状态服务。

```moonbit
let cache = sim.spawn_scripted_actor("cache", [
  HandlerRule::{ matcher: MatchPrefix("set "), action: PutFromParts(1, 2) },
  HandlerRule::{ matcher: MatchPrefix("get "), action: GetFromParts(1) },
])
```

验收点：

- 不需要新增内置 `ActorKind` 就能创建自定义 receive 行为。
- 可以结合 `TypedActorRef[T]` 使用业务 enum/struct 作为消息入口。

## 场景 C：监督树故障恢复

用户通过 `spawn_child` 建立父子 actor，再用 `supervise_with_limit` 模拟失败后的 stop/restart。

验收点：

- `children_of` 和 `parent_of` 能查询父子关系。
- stop 会级联停止子树。
- restart limit 用完后 actor 会停止，并记录 `RestartLimitExceeded`。

## 场景 D：trace 文件生成与 replay

```powershell
moon run cmd/moonsim -- trace kv_cluster --seed 42 --out tmp_trace.json --format json
moon run cmd/moonsim -- replay file tmp_trace.json --format json
```

验收点：

- JSON trace 是合法 JSON。
- 文件 replay 能读回 seed 和事件数量。
- archive 和 JSON 两种格式都可通过 runtime API 写入和校验。

## 场景 E：benchmark 报告

```powershell
moon run cmd/moonsim -- bench mailbox --messages 1000 --format markdown
moon run cmd/moonsim -- bench mailbox --messages 1000 --format json
```

验收点：

- 报告包含 messages、delivered、trace_events、virtual_time_ms、elapsed_us。
- JSON 输出可被工具解析，Markdown 输出可直接放入文档或申报材料。
