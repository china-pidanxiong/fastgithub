# 变更记录

## [2.1.1] - 2026-06-29

### 修复

- 修复鼠标滚轮滚动时界面不跟随的问题：重构布局，移除外层统一 ScrollViewer，各页面自行管理滚动区域（仪表盘 DataGrid 内部滚动、配置页整体滚动、日志页 ListBox 内部滚动），侧边栏滚轮事件正确转发到当前页面
- 修复点击右上角关闭按钮直接最小化到托盘无选项的问题：关闭时弹出确认对话框，可选择最小化到托盘或直接退出，支持记住选择并保存到配置

### 新增

- 配置页新增「界面行为」设置卡片，包含「关闭窗口时最小化到托盘」和「记住关闭选择」两个选项
- AppConfig 新增 `CloseToTray` 和 `RememberCloseChoice` 配置项

### 技术细节

- 主程序版本从 2.1.0 升至 2.1.1
- 修复 MainWindow.xaml.cs 中 `Application` 歧义引用编译错误（System.Windows.Forms 与 System.Windows 冲突）

## [2.1.0] - 2026-06-29

### 新增

- 应用图标设计（方案 A：渐变圆形 + G 字母 + 绿色对勾徽章），多尺寸 ICO（16/32/48/64/128/256）
- Octocat XAML 路径图标资源
- 图标生成脚本（Python + C# 工具项目）
- `AGENTS.md` AI 代理项目指南
- 暗色主题样式系统：5 个资源字典（颜色/按钮/控件/表格/侧边栏）
- 仪表盘运行概览统计卡片（域名总数/正常/超时/平均延迟）

### 变更

- 主窗口从 Tab 布局改为侧边栏导航 + 顶部标题栏布局
- 整体 UI 改为 GitHub 风格暗色主题（#0d1117 背景、#161b22 卡片）
- 仪表盘表格优化：暗色表头、斑马纹、统一行高和间距
- 配置页改为卡片式分组布局（域名列表/DNS/hosts路径/高级设置）
- 日志页增加级别颜色区分（Info蓝/Success绿/Warn黄/Error红）
- 系统托盘图标从代码绘制改为加载 ICO 文件
- Launcher 进度窗口改为暗色主题
- 发布脚本使用项目本地 `.dotnet` SDK

### 技术细节

- WPF 样式统一通过 ResourceDictionary 管理
- 按钮分为 Primary（绿色实心）和 Secondary（边框透明）两种风格
- 侧边栏导航项支持选中指示条和蓝色高亮效果
- 主程序版本从 2.0.2 升至 2.1.0

## [2.0.2] - 2026-06-27

### 新增

- 新增 `FastGithub.Launcher` 项目（.NET Framework 4.8）：自动检测 .NET 9 Desktop Runtime，未装时弹窗引导下载静默安装
- Launcher 启动即 UAC 提权，全程一次弹窗覆盖安装 + 主程序启动
- 新增 `ProgressForm` 进度窗口：无边框、可最小化、无关闭按钮，避免用户误中断
- 主程序 `app.manifest` 要求 UAC 提权（写 hosts 需要）

### 变更

- 主程序从自包含单文件（162 MB）改为 FrameworkDependent 单文件（~0.2 MB）
- 主程序 `AssemblyName` 改为 `FastGithub.App`，由 Launcher 启动
- `publish.ps1` 改为构建双 exe 并收集到 `publish/` 目录
- Runtime 版本固定 9.0.17（2026-06-09 发布的累积更新）

### 移除

- 移除主程序 `SelfContained=true`，改为 `SelfContained=false`

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
