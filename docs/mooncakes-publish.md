# Mooncakes 发布准备

本文档记录 MoonSim Actors 发布到 Mooncakes 前需要确认的事项。

## 当前包信息

| 字段 | 值 |
| --- | --- |
| name | `chenhao/moonsim-actors` |
| version | `0.1.0` |
| license | `Apache-2.0` |
| readme | `README.md` |
| repository | `https://github.com/chenh735/MoonSim-Actors` |
| dependency | `moonbitlang/x@0.4.45` |

## 发布前检查

```powershell
moon check
moon test
moon run cmd/moonsim -- run kv_cluster --seed 42
moon run cmd/moonsim -- bench mailbox --messages 1000 --format json
moon run cmd/moonsim -- trace kv_cluster --seed 42 --out tmp_trace.json --format json
moon run cmd/moonsim -- replay file tmp_trace.json --format json
```

## 发布步骤

1. 确认 GitHub 仓库已经推送最新代码。
2. 确认 `moon.mod` 的 `repository` 指向真实仓库。
3. 确认 `LICENSE` 和 `README.md` 已存在。
4. 按 Mooncakes 账号状态执行发布命令。

```powershell
moon publish
```

如果发布命令要求登录或授权，请按 MoonBit/Mooncakes 提示完成账号配置。

## 版本策略

- `0.1.0`：当前比赛原型版，包含 deterministic runtime、scripted actor、supervisor tree、trace file、benchmark reports。
- `0.2.0`：可考虑引入更完整的 actor trait、组合故障模型和更强 replay 校验。
- `1.0.0`：API 稳定后再发布。
