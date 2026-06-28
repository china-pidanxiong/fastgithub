# FastGithub

GitHub hosts 加速 Windows 桌面工具。

很多场景下访问 GitHub 慢、git push/pull 失败，根本原因是本地 DNS 解析出来的 IP 不可达或被污染。FastGithub 绕开系统 DNS，用公共 DNS 服务器直接解析 GitHub 各域名，挑出 443 通 + Ping 最低的 IP，写回 Windows hosts 文件。

## 交付清单

| 项 | 内容 |
|---|---|
| 版本 | 2.0.2（见 [CHANGELOG.md](CHANGELOG.md)） |
| 源码 | [src/FastGithub/](src/FastGithub)（主程序）+ [src/FastGithub.Launcher/](src/FastGithub.Launcher)（引导器） |
| 配置模板 | [src/FastGithub/config.example.json](src/FastGithub/config.example.json) |
| 解决方案 | [FastGithub.sln](FastGithub.sln) |
| 文档 | 本文件（使用说明 + 技术栈 + 架构）、[CHANGELOG.md](CHANGELOG.md)（发布说明）、[docs/PRODUCT.md](docs/PRODUCT.md)（产品介绍） |
| 测试 | `tests/FastGithub.Tests/` + `tests/FastGithub.Launcher.Tests/`（已加入 .gitignore，本地保留） |
| 双 exe 产物 | `publish/FastGithub.exe`（~12 KB 引导器）+ `publish/FastGithub.App.exe`（~220 KB 主程序）+ `config.example.json` |

## 技术栈

| 层 | 技术 |
|---|---|
| 主程序运行时 | .NET 9（`net9.0-windows`），FrameworkDependent |
| 引导器运行时 | .NET Framework 4.8（Windows 10/11 自带，零依赖） |
| UI 框架 | WPF（`<UseWPF>true</UseWPF>`） |
| 系统托盘 | WinForms 互操作（`<UseWindowsForms>true</UseWindowsForms>`，用 `NotifyIcon`） |
| 引导器 UI | WinForms（进度窗口、MessageBox） |
| 架构模式 | MVVM（Models / Core / Services / ViewModels / Views） |
| DNS 协议 | 手写 DNS 报文编解码（UDP 直连 53 端口，不依赖 `System.Net.Dns`） |
| 网络测试 | TCP 443 端口连通性 + `System.Net.NetworkInformation.Ping` 延迟选优 |
| 配置 | `System.Text.Json` 读写 `config.json`，首次运行从 `config.example.json` 复制 |
| 日志 | 自实现 `LogService`（文件句柄 + 锁），输出到 `github-hosts-update.log` |
| 测试 | xUnit + .NET Test SDK，单元测试 + 集成测试分类（`[Trait("Category","Integration")]`） |
| 发布 | 主程序单文件 FrameworkDependent（~220 KB）+ 引导器 .NET Framework 4.8（~12 KB） |

## 工作原理

1. **DNS 直连**：手写 DNS 协议报文（UDP），直连配置里的公共 DNS（默认 114/腾讯/阿里/Google/Cloudflare），不读本地 hosts，避免被污染。
2. **端口连通性测试**：对每个候选 IP 测 443 端口是否可连。
3. **Ping 选优**：从 443 可达的 IP 中选延迟最低的写入 hosts。
4. **标记块管理**：写 hosts 时用 `# === GitHub Hosts Start (Managed by FastGithub) ===` / `End ===` 包裹，下次刷新只替换这个块，不动用户其他条目。
5. **DNS 缓存刷新**：写完调用 `ipconfig /flushdns` 让新条目立即生效。

## 启动流程（2.0.2 新增）

```
用户双击 FastGithub.exe（引导器）
        │
        ▼
UAC 提权（引导器 manifest 要求 requireAdministrator）
        │
        ▼
检测 %ProgramFiles%\dotnet\shared\Microsoft.WindowsDesktop.App\9.x
        │
        ├── 已装 .NET 9 Runtime ───► 启动 FastGithub.App.exe → 引导器退出
        │
        ▼ 未装
弹窗：「未检测到 .NET 9 Desktop Runtime，是否自动下载并安装？」
        │
        ├── 选「否」 ──────────────► 引导器退出
        │
        ▼ 选「是」
进度窗口（可最小化）
  1. 下载 windowsdesktop-runtime-9.0.17-win-x64.exe（~58 MB）
     进度条显示百分比
  2. 静默安装：/quiet /norestart
     进度条切 Marquee 动画
        │
        ├── 安装成功 ──────────────► 启动 FastGithub.App.exe → 引导器退出
        │
        ▼ 安装失败
弹窗提示错误码 + 手动下载链接 → 引导器退出
```

## 前置条件

- Windows 10 / 11 x64
- 管理员权限（修改 hosts 文件必须，引导器启动即触发 UAC）
- **无需预装 .NET 9 Runtime**——引导器会自动检测并安装

## 使用

1. 双击 `FastGithub.exe`（引导器），会弹 UAC 提权请求，点是。
2. 首次运行若未装 .NET 9 Runtime，引导器会弹窗询问是否自动下载安装，选「是」等待进度条走完。
3. 主程序 `FastGithub.App.exe` 启动后，主窗口有三个标签页：
   - **仪表盘**：点击"立即刷新"，实时看到每个域名的解析/测试/写 hosts 进度，完成后表格列出每个域名当前 IP、状态、延迟、上次更新时间。
   - **配置**：增删要加速的域名、增删 DNS 服务器、调整最大备份数和超时。保存后下次刷新立即生效，不必重启程序。
   - **日志**：所有刷新过程日志按时间顺序显示，可按级别过滤、可一键用记事本打开完整日志文件。
4. 关闭主窗口会最小化到系统托盘，不会退出程序。右键托盘图标可"立即刷新"或"显示主窗口"或"退出"。
5. 首次最小化到托盘时会弹气泡提示，之后不再打扰。

## 配置

配置文件 `config.json`（与 exe 同目录，首次运行自动从 `config.example.json` 复制）。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `Domains` | string[] | github.com 等 23 个域名 | 需要加速的域名列表 |
| `DnsServers` | string[] | 114.114.114.114 / 119.29.29.29 / 223.5.5.5 / 8.8.8.8 / 1.1.1.1 | 候选 DNS 服务器，按顺序尝试，第一个成功即用 |
| `HostsPath` | string | `C:\Windows\System32\drivers\etc\hosts` | hosts 文件路径，一般不要改 |
| `MaxBackupCount` | int | 10 | hosts 备份保留份数，超出自动删最旧的 |
| `TimeoutMs` | int | 3000 | DNS / TCP 443 / Ping 单次操作超时（毫秒） |

修改后点击配置页底部"保存"按钮即可，下次刷新会用新配置。

## 构建

```bash
dotnet build
```

## 发布双 exe

使用发布脚本（沙箱 workaround + 收集交付物）：

```powershell
powershell -ExecutionPolicy Bypass -File .superpowers/publish.ps1
```

产物路径：`publish/`

| 文件 | 大小 | 说明 |
|---|---|---|
| `FastGithub.exe` | ~12 KB | 引导器（.NET Framework 4.8，Windows 自带，零依赖） |
| `FastGithub.App.exe` | ~220 KB | 主程序（FrameworkDependent 单文件，不含 .NET 运行时） |
| `config.example.json` | ~1 KB | 配置模板 |

首次运行时引导器会自动检测并安装 .NET 9 Desktop Runtime（~58 MB，一次性）。

## 测试

```bash
dotnet test
```

测试分两个项目：
- `FastGithub.Tests`（主程序）：19 个测试
- `FastGithub.Launcher.Tests`（引导器）：9 个测试

测试分类：
- 单元测试（默认运行）：用 fake 接口隔离真实网络，覆盖 HostsUpdater 选优逻辑、HostsFileManager 标记块管理、ConfigService 配置读写、DnsResolver 协议编解码、RuntimeDetector/RuntimeInstaller 常量与路径。
- 集成测试（默认也运行，但可排除）：`NetworkTesterTests` 中两个测试真实访问 `192.0.2.1`（TEST-NET-1 保留地址）验证超时返回 false/null。

排除集成测试：
```bash
dotnet test --filter Category!=Integration
```

## 常见问题

**Q: 刷新后访问 GitHub 还是慢？**
A: 浏览器有 DNS 缓存，重启浏览器或 `ipconfig /flushdns` 后再试。Chrome 内部还有自己的 DNS 缓存（chrome://net-internals/#dns 清空）。

**Q: 杀毒软件拦截 hosts 写入？**
A: 部分杀软会保护 hosts 文件。把 `FastGithub.exe` 加入信任列表即可。备份文件 `hosts.githubbak.*` 同目录可手动恢复。

**Q: 程序显示"刷新失败: 拒绝访问"？**
A: 没有管理员权限。重新启动 `FastGithub.exe`，在 UAC 弹窗点"是"。

**Q: 如何彻底清除 FastGithub 写入的 hosts 条目？**
A: 直接编辑 hosts 文件，删除 `# === GitHub Hosts Start (Managed by FastGithub) ===` 到 `End ===` 之间的所有内容。也可以在程序里"重置为默认"再"保存"再"刷新"覆盖。

**Q: 程序退出后 hosts 还有效吗？**
A: 有效。hosts 是 Windows 系统级配置，FastGithub 只负责写入，程序退出不影响已写入的条目，直到下次 Windows DNS 缓存过期或被其他工具覆盖。

**Q: 引导器下载 Runtime 失败怎么办？**
A: 弹窗会附带下载链接，可手动下载安装。直链：`https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/9.0.17/windowsdesktop-runtime-9.0.17-win-x64.exe`。安装后再次双击引导器即可直接启动主程序。

## 项目结构

```
src/
├── FastGithub/                  主程序（.NET 9 WPF）
│   ├── Models/                  AppConfig / HostsEntry / UpdateProgress / UpdateResult / LogLevel
│   ├── Core/                    DnsResolver / HostsFileManager / HostsUpdater / NetworkTester + 接口
│   ├── Services/                ConfigService / LogService / TrayService
│   ├── ViewModels/              DashboardViewModel / ConfigViewModel / LogViewModel / MainWindowViewModel / ViewModelBase / RelayCommand
│   ├── Views/                   DashboardView / ConfigView / LogView（XAML + 后缀代码）
│   ├── App.xaml                 应用资源
│   ├── App.xaml.cs              入口：UAC 检测 + 依赖注入
│   ├── MainWindow.*             主窗口（标签页容器）
│   ├── app.manifest             UAC 提权（写 hosts 需要）
│   └── config.example.json      默认配置模板
└── FastGithub.Launcher/         引导器（.NET Framework 4.8）
    ├── Program.cs               入口：编排检测→弹窗→安装→启动主程序
    ├── RuntimeDetector.cs       检测 .NET 9 Desktop Runtime 是否已安装
    ├── RuntimeInstaller.cs      下载 + 静默安装，带进度回调
    ├── ProgressForm.cs          WinForms 进度窗口（可最小化）
    ├── app.manifest             UAC 提权（requireAdministrator）
    └── FastGithub.Launcher.csproj

tests/                           测试项目（已加入 .gitignore，本地保留）
├── FastGithub.Tests/            主程序测试（19 个）
└── FastGithub.Launcher.Tests/   引导器测试（9 个）
```

## 开发说明

- **架构**：MVVM。Models 层纯数据；Core 层无 UI 依赖，可独立测试；Services 持有外部资源（文件/托盘）；ViewModels 编排 UI 状态；Views 纯 XAML。
- **DNS 协议**：`Core/DnsResolver.cs` 手写 DNS 报文（不依赖 System.Net.Dns），支持 A 记录查询与响应解析，UDP 直连 53 端口。
- **hosts 写入并发**：`HostsFileManager.Read/Write` 带 5 次重试 + 500ms 间隔，应对杀软短暂锁定文件。
- **托盘**：WPF 与 WinForms 互操作（NotifyIcon 在 WinForms），需要 `<UseWPF>true</UseWPF>` + `<UseWindowsForms>true</UseWindowsForms>` 同时开启。
- **UAC**：引导器与主程序都有 `app.manifest` 要求 `requireAdministrator`，启动即提权。
- **引导器线程模型**：UI 线程跑 `Application.Run(form)` 维护消息循环；worker 线程跑 `installer.Install()`（阻塞下载 + 静默安装）；事件回调通过 `BeginInvoke` 切回 UI 线程更新进度条。
- **Runtime 版本**：固定 .NET 9.0.17（2026-06-09 发布的累积更新）。URL 用 `builds.dotnet.microsoft.com` 稳定模式，避免旧 `download.visualstudio.microsoft.com` 的 hash 路径失效。

## 许可证

[MIT](LICENSE)

## 链接

- [产品介绍](docs/PRODUCT.md)
- [变更记录](CHANGELOG.md)
