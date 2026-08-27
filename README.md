# Usage Dashboard

一个 macOS 原生窗口，一眼查看多个 LLM 订阅的用量（5 小时 / 周 / 月窗口、余额与重置时间）。

- 内置支持：Kimi Code（`kimi`）、MiniMax M3（`minimax`）。
- 自定义服务商：配置「请求 + JavaScript extractor」，例如 CommandCode。
- 刷新频率：全局默认 600 秒，每个订阅可用 `refreshIntervalSec` 覆盖。
- 密钥：`apiKey` 字面量或 `apiKeyEnv` 引用环境变量。
- 配置：YAML 文件，内置图形化配置编辑器（增删改订阅、多行 extractor、保存前测试连接）。

## 安装（Homebrew）

通过 Homebrew Cask 安装，一条命令装到 `/Applications`（需 macOS 14+，Apple Silicon）：

```sh
brew tap kbyyd24/usage-dashboard
brew install --cask kbyyd24/usage-dashboard/usage-dashboard
```

卸载：`brew uninstall --cask` 只删应用；要**连配置一起清理**（`~/.config/usage-dash`）需加 `--zap`：

```sh
brew uninstall --cask --zap kbyyd24/usage-dashboard/usage-dashboard
```

> 说明：Cask 已声明 `zap trash: "~/.config/usage-dash"`，但 Homebrew 只在 `--zap` 时才执行。
> 该 Cask 指向本仓库 tag 触发构建的 GitHub Release artifact；应用为 arm64、未公证（ad-hoc 签名）。

## 构建与测试

本机使用 CommandLineTools（无完整 Xcode）。

```sh
swift build          # 编译
./scripts/test.sh    # 运行 Swift Testing（自动注入 Testing 框架路径）
```

## 运行

```sh
cp docs/config.example.yaml ~/.config/usage-dash/config.yaml
# 填入密钥（或设置对应环境变量），也可启动后在应用内用「配置」按钮编辑
swift run
```

配置文件路径默认 `~/.config/usage-dash/config.yaml`，可用环境变量 `USAGE_DASH_CONFIG` 覆盖。
旧版 `config.json` 会在首次启动时自动迁移为 `config.yaml`（原 json 文件保留）。

## 图形化配置

启动后在窗口右上角点「配置」按钮：

- 增/删/改订阅；内置类型（Kimi / MiniMax）只需名称与密钥，自定义类型还需 url / method / headers / body / extractor。
- extractor 用多行文本域编辑，保存后以 YAML 块文本落盘，可读可写。
- 每个订阅可点「测试连接」，保存前用真实请求 + extractor 验证并展示结果（10 秒超时）。

## 打包

```sh
./scripts/package.sh [version]
# 产出 dist/UsageDashboard.app 与 dist/UsageDashboard-<version>-macos-arm64.zip
# 应用为 arm64、ad-hoc 签名（未公证），首次双击需右键→打开
```

发布：推送 `v*` tag（如 `v0.1.0`）触发 `.github/workflows/release.yml`，自动构建 zip 并发布 GitHub Release；
发布同时会把 `Casks/usage-dashboard.rb` 的 version/sha256 回写并提交回 `main`。

## 配置示例

见 `docs/config.example.yaml`。自定义 provider 的 `extractor` 是一段 `function(response) { ... }`，
返回 `{ status, message, rows }`；`rows` 支持：

- 窗口行：`{ "kind": "window", "label": "5 小时", "used": 0.49, "cap": 14, "resetAt": 1787554846343 }`
  （`resetAt` 为毫秒时间戳）
- 余额行：`{ "kind": "balance", "label": "月度余额", "balance": 69.5, "unit": "credits" }`

`{{apiKey}}` 占位符会替换为解析后的密钥（`apiKeyEnv` 或 `apiKey`）。
