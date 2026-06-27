# 变更记录

## [2.0.1] - 2026-06-27

### 文档与代码风格整理

- 重写 README.md：补充项目背景、工作原理 5 步、配置字段表、5 个常见问题、项目结构、开发说明，从模板化五段式改为工程师视角
- 新增 CHANGELOG.md
- 新增 .gitignore：忽略 bin/obj、本地 SDK、NuGet 缓存、IDE 文件、构建产物、运行时配置等

### 代码质量

- 引入 `UpdateResult` record 替换 `Task<(int success, int total, Dictionary<string, long> latencies)>` 元组签名，调用方用 `result.Success`/`result.Total`/`result.Latencies` 替代解构
- 重命名 `ConfigViewModel.RemoveSelectedDomain` → `RemoveDomain`，`RemoveSelectedDnsServer` → `RemoveDnsServer`
- 清理冗余 XML summary：移除全部"名字翻译式"的 `/// <summary>`（约 50 处），保留有信息增量的（如 DnsResolver 协议说明、HostsUpdater 流程说明、ConfigService.Load 行为说明）
- 清理套路化措辞："兜底："、"备注："、解释性括号注释
- ConfigService.Load 默认值补齐逻辑优化：提取 `var def = AppConfig.CreateDefault()` 避免重复构造，新增 `MaxBackupCount`/`TimeoutMs` 非法值回退（避免 0 超时导致刷新流程瘫痪）
- TrayService.ShowBalloon 内部封装 Dispatcher 调用，把线程模型收敛到服务内部（修复后台线程调用 NotifyIcon 跨线程风险）

### 测试

- 新增 `Load_TimeoutMsZero_FallsBackToDefault` / `Load_MaxBackupCountNegative_FallsBackToDefault` 两个 ConfigService 测试
- HostsUpdaterTests 测试方法重命名更贴合场景（如 `UpdateAsync_AllPort443Fail_FallbackToFirstIp` → `UpdateAsync_AllPort443Fail_FallsBackToFirstIpAndOmitsLatency`）
- 删除测试中复述断言的 inline 注释

### 交付文档

- README 新增"交付清单"小节，集中列出版本、源码、配置、文档、测试、产物路径
- README 新增"技术栈"小节，集中列出运行时 / UI / 托盘 / 架构 / DNS / 网络测试 / 配置 / 日志 / 测试 / 发布十类技术选型
- 修正 csproj `<Version>` 从 `1.0.0` 对齐到 `2.0.1`，与 CHANGELOG 一致
- .gitignore 扩展：忽略 `.superpowers/`、`docs/superpowers/`、`tests/` 三个整目录（本地保留，不提交）

## [2.0.0] - 2026-06-27

### 重构：从 PowerShell 脚本改造为 WPF 桌面应用

原项目是 PowerShell + 浏览器扩展双工具：`Update-GitHubHosts.ps1` 命令行刷新 hosts，`GitHubHostsServer.ps1` 起本地 HTTP 服务给浏览器扩展查 IP，`GitHubHostsWidget.ps1` 是悬浮窗。改造后统一为单个 WPF 桌面应用，删除浏览器扩展。

### 新增

- WPF 主窗口 + 系统托盘（关闭最小化到托盘，不退出）
- 仪表盘 Tab：一键刷新 + 实时进度 + 域名表格（IP/状态/延迟/上次更新）
- 配置 Tab：域名 / DNS 服务器列表可增删改，保存后立即生效（不必重启）
- 日志 Tab：级别过滤 + 记事本打开完整日志
- 手写 DNS 协议解析器（UDP 直连公共 DNS，绕过本地 hosts 污染）
- 443 端口连通性测试 + Ping 延迟选优，从候选 IP 中挑最快
- hosts 标记块管理（`# === GitHub Hosts Start/End ===`），仅替换本工具写入的条目
- hosts 文件备份（按时间戳命名，超过上限自动删旧）
- 启动 UAC 自动提权（修改 hosts 必须）
- 单文件发布（self-contained，目标机器无需另装 .NET）
- xUnit 单元测试 + 集成测试标记（17 个测试，可 `--filter Category!=Integration` 排除集成测试）

### 删除

- `Update-GitHubHosts.ps1`、`GitHubHostsServer.ps1`、`GitHubHostsWidget.ps1`
- `browser-extension/` 目录（浏览器扩展不再需要）
- `一键刷新.bat`、`启动悬浮工具.bat`、`启动本地服务.bat`
- `github-hosts-update.log`（运行时生成）

### 改进

- 配置从 `.ps1` 内硬编码改为 `config.json`，UI 可编辑
- 域名匹配从 `string.Contains` 改为严格 token 比较，避免子串误匹配（如 `api.github.com` 误中 `github.com`）
- DNS 报文解析修复：`nscount + arcount` 字段 4 字节而非 8 字节（原实现跳过 8 字节，会读错 Answer 段）
- 托盘图标 GDI 资源加 `using`，避免句柄泄漏
- 异步刷新异常加 try/catch，避免 async void 未观察异常导致程序崩溃
