# MoonSim Actors 进程视图

进程视图描述运行时的动态流程。当前版本是单进程、单 runtime、确定性事件循环。

## tell 流程

```text
ActorRef.tell
-> SimRuntime.tell_to
-> Envelope
-> schedule_message
-> FaultRule
-> ScheduledEvent
-> run_all
-> apply_deliver
-> mailbox
-> handler side effect
-> trace
```

## ask/reply 流程

```mermaid
sequenceDiagram
    participant Caller
    participant Runtime as SimRuntime
    participant Actor as ActorCell
    participant Handler as Handler

    Caller->>Runtime: ask(payload, timeout)
    Runtime->>Runtime: schedule request
    Runtime->>Runtime: schedule timeout
    Runtime->>Actor: deliver Envelope
    Actor->>Handler: dispatch ActorKind
    alt handler replies first
        Handler->>Runtime: AskReply
        Runtime->>Caller: AskOk(response)
    else timeout fires first
        Runtime->>Caller: AskErr(Timeout)
    end
```

`Sink` actor 保留兼容路径：请求投递成功后直接返回原始 envelope。`Echo`、KV 和 `Scripted` actor 通过 handler reply。

## scripted handler 流程

```text
deliver Envelope
-> ActorKind.Scripted
-> 按顺序扫描 HandlerRule
-> HandlerMatch 命中
-> HandlerAction
   - ReplyText
   - ReplyWithPayload
   - PutFromParts
   - GetFromParts
   - NoAction
-> 更新 actor state 或生成 AskReply
-> trace
```

## supervisor 流程

```text
spawn_child
-> ActorCell.parent
-> parent.children

supervise_with_limit(actor, Restart, n)
-> ActorFailed trace
-> restart_count 检查
-> restart_actor_tree 或 stop_actor_tree
```

`stop` 和 `restart` 都会作用到 actor 的子树，便于模拟服务节点故障和恢复。

## trace/replay 流程

```text
trace_archive / trace_json
-> write_trace_file
-> replay_trace_file
-> replay_trace_archive 或 replay_trace_json
-> ReplayCheck
```

JSON replay 会先用 `@json.valid` 校验文档合法性，再读取 seed 和事件数量。

## benchmark 流程

```text
run_mailbox_bench
-> monotonic_clock_start
-> 构造 runtime 并发送 N 条消息
-> run_all
-> monotonic_clock_end
-> BenchSummary
-> text / Markdown / JSON
```
