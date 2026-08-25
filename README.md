# Usage Dashboard

一个 macOS 原生窗口，一眼查看多个 LLM 订阅的用量（5 小时 / 周 / 月窗口、余额与重置时间）。

- 内置支持：Kimi Code（`kimi`）、MiniMax M3（`minimax`）。
- 自定义服务商：配置「请求 + JavaScript extractor」，例如 CommandCode。
- 刷新频率：全局默认 600 秒，每个订阅可用 `refreshIntervalSec` 覆盖。
- 密钥：`apiKey` 字面量或 `apiKeyEnv` 引用环境变量。

## 构建与测试

本机使用 CommandLineTools（无完整 Xcode）。

```sh
swift build          # 编译
./scripts/test.sh    # 运行 Swift Testing（自动注入 Testing 框架路径）
```

## 运行

```sh
cp docs/config.example.json ~/.config/usage-dash/config.json
# 编辑配置，填入密钥（或设置对应环境变量）
swift run
```

配置文件路径默认 `~/.config/usage-dash/config.json`，可用环境变量 `USAGE_DASH_CONFIG` 覆盖。

## 打包

```sh
./scripts/package.sh
# 产出 dist/UsageDashboard.app，可双击运行（未签名）
```

## 配置示例

见 `docs/config.example.json`。自定义 provider 的 `extractor` 是一段 `function(response) { ... }`，
返回 `{ status, message, rows }`；`rows` 支持：

- 窗口行：`{ "kind": "window", "label": "5 小时", "used": 0.49, "cap": 14, "resetAt": 1787554846343 }`
  （`resetAt` 为毫秒时间戳）
- 余额行：`{ "kind": "balance", "label": "月度余额", "balance": 69.5, "unit": "credits" }`

`{{apiKey}}` 占位符会替换为解析后的密钥（`apiKeyEnv` 或 `apiKey`）。
