# FastGithub 产品介绍

## 一句话定位

GitHub hosts 加速 Windows 桌面工具——双击即用，自动挑最快的 GitHub IP 写回 hosts，解决 git push/pull 慢、网页打不开的问题。

## 解决什么问题

| 症状 | 根因 | FastGithub 怎么处理 |
|---|---|---|
| git clone/push/pull 卡住或超时 | 本地 DNS 解析的 GitHub IP 不可达或被污染 | 绕开系统 DNS，直连公共 DNS 解析 |
| 访问 github.com 网页慢 | 同上，IP 不优 | 测 443 端口连通性 + Ping 选延迟最低的 IP |
| 切换网络后 GitHub 又慢了 | 不同网络环境下最优 IP 不同 | 一键刷新，自动重新选优 |
| 不敢动 hosts 怕搞坏 | 手改 hosts 容易破坏其他条目 | 标记块管理，只动 FastGithub 自己的块 |

## 核心特性

### 1. DNS 直连绕开污染

手写 DNS 协议报文（UDP 53 端口），直连配置里的公共 DNS（默认 114/腾讯/阿里/Google/Cloudflare），完全不读本地 hosts 和系统 DNS，从源头避免被污染。

### 2. 三段式选优

```
DNS 解析多候选 IP → TCP 443 端口连通性测试 → Ping 延迟选优 → 写入 hosts
```

不是简单用第一个解析结果，而是从所有候选 IP 中挑出 443 通 + Ping 最低的。

### 3. 标记块管理

写 hosts 时用 `# === GitHub Hosts Start (Managed by FastGithub) ===` / `End ===` 包裹。下次刷新只替换这个块，不动用户其他条目。要彻底清除？直接删这个块即可。

### 4. 可视化桌面应用

不是命令行工具，是完整的 WPF 桌面应用：
- **仪表盘**：实时刷新进度，完成后表格列出每个域名的 IP / 状态 / 延迟 / 上次更新时间
- **配置**：图形化增删域名、DNS 服务器、调整备份份数和超时
- **日志**：按级别过滤、一键用记事本打开完整日志文件

### 5. 系统托盘常驻

关闭主窗口最小化到托盘，不退出程序。右键托盘图标可「立即刷新」或「显示主窗口」或「退出」。首次最小化会弹气泡提示，之后不再打扰。

### 6. 引导器自动安装 Runtime（2.0.2 新增）

主程序基于 .NET 9 WPF，但目标机器不一定装了 .NET 9 Runtime。引导器（Launcher）用 .NET Framework 4.8（Windows 10/11 自带，零依赖）做检测：

- 已装 .NET 9 → 直接启动主程序
- 未装 → 弹窗询问是否自动下载安装
  - 选「是」→ 进度窗口下载 + 静默安装 → 启动主程序
  - 选「否」→ 引导器退出

最终交付物只有 3 个文件：

| 文件 | 大小 | 说明 |
|---|---|---|
| `FastGithub.exe` | ~12 KB | 引导器，双击这个 |
| `FastGithub.App.exe` | ~220 KB | 主程序 |
| `config.example.json` | ~1 KB | 配置模板 |

## 与同类工具对比

| 特性 | FastGithub | SwitchHosts | 手改 hosts |
|---|---|---|---|
| 自动选最快 IP | ✅ DNS 直连 + 443 + Ping | ❌ 需手动填 IP | ❌ 需手动填 IP |
| 可视化界面 | ✅ WPF 桌面应用 | ✅ Electron 应用 | ❌ 命令行/记事本 |
| 系统托盘常驻 | ✅ 一键刷新 | ✅ | ❌ |
| 标记块管理 | ✅ 不动其他条目 | ❌ 全文替换 | ❌ 容易误删 |
| hosts 备份 | ✅ 自动备份 + 自动清理 | ❌ | ❌ |
| 安装包体积 | ~230 KB（3 文件） | ~80 MB（Electron） | 0 |
| 运行时依赖 | .NET 9 Runtime（引导器自动装） | 自带 Electron 运行时 | 无 |

## 性能

- 23 个 GitHub 域名全量刷新：约 5-15 秒（取决于网络环境和 `TimeoutMs` 配置）
- 单个域名选优：DNS 解析 + 443 测试 + Ping 并行，约 0.5-2 秒
- 主程序内存占用：~80 MB（.NET 9 WPF 应用常规水平）

## 安全性

- **hosts 备份**：每次写入前自动备份到 `hosts.githubbak.{时间戳}`，按 `MaxBackupCount`（默认 10）自动清理旧备份
- **UAC 提权**：修改 hosts 需要管理员权限，引导器与主程序都有 `app.manifest` 要求 `requireAdministrator`
- **不改系统其他文件**：只动 hosts 文件和同目录的 `config.json` / `github-hosts-update.log`
- **不联网收集数据**：DNS 请求直连公共 DNS 服务器，不上报任何用户信息

## 适用场景

- 国内访问 GitHub 慢、git 操作失败
- 切换网络环境后需要重新选最优 GitHub IP
- 不想手改 hosts、不想用命令行
- 希望有可视化的刷新进度和配置界面
- 团队内分发：3 文件拷过去就能用，引导器自动装 Runtime

## 不适用场景

- Linux / macOS（仅支持 Windows）
- 需要代理流量（FastGithub 只改 hosts，不代理）
- 需要修改 GitHub 之外网站的 hosts（可在配置里加域名，但工具定位是 GitHub 加速）

## 技术栈速览

| 层 | 技术 |
|---|---|
| 主程序 | C# .NET 9 WPF（MVVM 架构） |
| 引导器 | C# .NET Framework 4.8 WinForms |
| DNS 协议 | 手写 UDP 报文编解码（不依赖 System.Net.Dns） |
| 测试 | xUnit，28 个测试（19 主程序 + 9 引导器） |
| 体积 | ~230 KB（3 文件交付物） |

## 路线图

- ✅ 2.0.0：从 PowerShell 脚本改造为 WPF 桌面应用
- ✅ 2.0.1：代码质量整理（UpdateResult record、方法重命名、AI 味清理）
- ✅ 2.0.2：引入引导器自动装 Runtime，体积从 162 MB 降到 230 KB
- 🔜 未来：IPv6 支持、定时自动刷新、配置导入导出

## 许可证

MIT，可自由使用、修改、分发、商业使用，只需保留版权声明。

## 链接

- [GitHub 仓库](https://github.com/china-pidanxiong/fastgithub)
- [使用说明（README）](../README.md)
- [变更记录](../CHANGELOG.md)
