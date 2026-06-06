# MoonSim Actors TODO 完成记录

本文档记录本轮从未实现目标收敛出的 TODO，以及每项对应的实现、测试和验证状态。

## 本轮 TODO

| 状态 | 目标 | 实现位置 | 测试位置 |
| --- | --- | --- | --- |
| Done | 类型化消息入口，不再只能让调用者裸写字符串 | `types.mbt`, `runtime.mbt` | `typed_scripted_wbtest.mbt` |
| Done | 用户可配置 actor receive handler | `types.mbt`, `runtime.mbt` | `typed_scripted_wbtest.mbt` |
| Done | supervisor tree：父子关系、级联 stop/restart、restart limit | `types.mbt`, `runtime.mbt` | `supervisor_tree_wbtest.mbt` |
| Done | trace JSON 输出、JSON replay 校验 | `runtime.mbt`, `demo.mbt` | `trace_file_wbtest.mbt` |
| Done | trace 文件读写和文件 replay | `runtime.mbt`, `demo.mbt`, `cli.mbt` | `trace_file_wbtest.mbt`, `benchmark_reports_wbtest.mbt` |
| Done | benchmark 真实耗时统计、Markdown/JSON 报告 | `types.mbt`, `demo.mbt`, `cli.mbt` | `benchmark_reports_wbtest.mbt` |
| Done | CLI 支持 trace 文件生成和 replay 文件读取 | `cli.mbt`, `cmd/moonsim` | `benchmark_reports_wbtest.mbt`, `cli_wbtest.mbt` |
| Done | Mooncakes 发布准备元数据 | `moon.mod`, `README.md`, `docs/mooncakes-publish.md` | `moon check` |
| Done | 正式 LICENSE 文件 | `LICENSE`, `moon.mod` | 人工核对 |
| Done | 比赛申报材料草稿 | `docs/osc2026-submission.md` | 人工核对 |
| Done | 更新 README 与全部 docs 文档 | `README.md`, `docs/*.md` | `moon check`, `moon test` |

## 说明

Mooncakes 的真实发布动作需要你的 MoonBit/Mooncakes 账号状态和仓库发布权限，因此本轮完成的是本地发布准备：包元数据、LICENSE、README、发布命令说明和申报草稿。真正执行发布时按 `docs/mooncakes-publish.md` 操作。

## 已验证命令

```text
moon check
moon test
moon run cmd/moonsim -- run kv_cluster --seed 9
moon run cmd/moonsim -- bench mailbox --messages 5
moon run cmd/moonsim -- bench mailbox --messages 5 --format json
moon run cmd/moonsim -- trace kv_cluster --seed 9 --out tmp_cli_trace.json --format json
moon run cmd/moonsim -- replay file tmp_cli_trace.json --format json
moon run examples/kv_cluster
moon run bench/mailbox
```

## 当前测试状态

当前测试数量：24 个，全部通过。
