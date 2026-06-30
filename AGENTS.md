# AGENTS.md - AI 代理项目指南

本文件供 AI 编程助手（Claude / Cursor / TRAE 等）快速了解项目结构和开发约定。

## 项目概览

**FastGithub** - GitHub Hosts 加速器，通过自动获取 GitHub 域名的最佳 IP 并写入系统 hosts 文件来加速访问。

- **主程序**：FastGithub.App.exe（WPF，.NET 9，FrameworkDependent 单文件）
- **引导器**：FastGithub.exe（WinForms，.NET Framework 4.8）
- **架构**：引导器检测 .NET 9 Desktop Runtime，缺失则自动安装，然后启动主程序

### 已知问题与注意事项

- **Windows 智能应用控制阻止**：未签名的 exe 可能被 Smart App Control 阻止运行。解决方案：使用代码签名证书签名（见「代码签名」章节）
- **自签名证书限制**：自签名证书仅在安装了该证书的电脑上受信任，发布给其他用户需使用正式 CA 签发的代码签名证书

## 构建环境

- 始终使用项目本地 `.dotnet\dotnet.exe`，不要使用系统 `dotnet`（系统可能只有 Runtime）
- .NET SDK 版本：9.0.315
- 主程序目标框架：`net9.0-windows`
- 引导器目标框架：`net48`

## 项目结构

```
fastgithub/
├── src/
│   ├── FastGithub/              # 主程序（WPF, MVVM）
│   │   ├── Assets/              # 图标资源（ICO, SVG, XAML）
│   │   ├── Styles/              # WPF 样式资源字典
│   │   ├── Core/                # 核心业务逻辑（DNS解析、hosts管理等）
│   │   ├── Models/              # 数据模型
│   │   ├── Services/            # 服务（配置、日志、托盘）
│   │   ├── ViewModels/          # MVVM ViewModel
│   │   └── Views/               # WPF 用户控件
│   ├── FastGithub.Launcher/     # .NET 4.8 引导器
│   └── FastGithub.Tools/        # 工具（图标生成等）
├── tests/
│   ├── FastGithub.Tests/        # 主程序单元测试
│   └── FastGithub.Launcher.Tests/ # 引导器单元测试
├── scripts/
│   ├── publish.ps1              # 发布脚本（支持代码签名）
│   └── New-CodeSigningCert.ps1  # 自签名证书生成脚本
├── docs/
│   └── PRODUCT.md               # 产品文档
└── FastGithub.sln
```

## 常用命令

```powershell
# 构建
.\.dotnet\dotnet.exe build src\FastGithub\FastGithub.csproj -c Release

# 测试
.\.dotnet\dotnet.exe test tests\FastGithub.Tests\FastGithub.Tests.csproj -c Release

# 打包发布（无签名）
.\scripts\publish.ps1

# 打包发布（带签名，使用证书文件）
.\scripts\publish.ps1 -Sign -CertPath .\scripts\FastGithub.pfx -CertPassword yourpassword

# 打包发布（带签名，使用证书指纹）
.\scripts\publish.ps1 -Sign -CertThumbprint "证书指纹"
```

## 代码签名

### 签名工具与方式

项目发布脚本 `scripts/publish.ps1` 内置代码签名支持，自动检测并优先使用以下方式：

1. **signtool.exe**（Windows SDK，优先使用）
2. **Set-AuthenticodeSignature**（PowerShell 内置，备选方案）

支持两种证书来源：
- **证书文件**（.pfx/.p12）：通过 `-CertPath` 和 `-CertPassword` 指定
- **证书存储**：通过 `-CertThumbprint` 指定指纹，从当前用户或本地计算机的证书存储中查找

### 生成自签名证书（本地开发用）

```powershell
# 生成自签名代码签名证书（有效期 10 年，导出到 scripts/FastGithub.pfx）
.\scripts\New-CodeSigningCert.ps1 -Password "你的密码" -ValidYears 10
```

### 安装证书到受信任根（必须，否则 Smart App Control 仍会阻止）

**图形界面方式**：
1. 双击生成的 `.pfx` 文件
2. 存储位置选择「本地计算机」→ 下一步
3. 输入证书密码 → 下一步
4. 选择「将所有的证书都放入下列存储」→ 浏览 → 选择「受信任的根证书颁发机构」→ 确定
5. 下一步 → 完成

**PowerShell 方式**（需管理员权限）：
```powershell
Import-PfxCertificate -FilePath ".\scripts\FastGithub.pfx" `
    -CertStoreLocation Cert:\LocalMachine\Root `
    -Password (ConvertTo-SecureString '你的密码' -AsPlainText -Force)
```

### 签名常见问题

| 问题 | 原因 | 解决方案 |
|------|------|----------|
| **Smart App Control 仍阻止运行** | 自签名证书未安装到受信任根 | 将证书安装到「本地计算机」的「受信任的根证书颁发机构」 |
| **签名失败：找不到 signtool.exe** | 未安装 Windows SDK | 脚本会自动回退到 PowerShell 的 Set-AuthenticodeSignature，不影响使用 |
| **时间戳服务连接失败** | 网络问题或时间戳服务器不可用 | 可通过 `-TimeStampUrl` 参数更换时间戳服务器，或忽略时间戳（无时间戳的签名在证书过期后失效） |
| **其他电脑运行仍提示不安全** | 自签名证书仅在本机受信任 | 发布给他人需使用正式 CA 签发的代码签名证书（如 Certum 开源免费证书、DigiCert、Sectigo 等） |
| **证书密码包含特殊字符** | PowerShell 参数解析问题 | 使用单引号包裹密码，或通过 Read-Host 交互式输入 |

### 正式发布建议

如需发布给其他用户使用，推荐以下证书方案：
- **Certum Open Source**：开源项目可免费申请，需身份验证
- **OV 代码签名证书**：约 500-2000 元/年，个人/企业均可申请
- **EV 代码签名证书**：约 2000-5000 元/年，SmartScreen 即时信任
- **Microsoft Store 发布**：约 120 元/年开发者账号，自动获得信任

## 代码约定

- 语言：C#
- MVVM 架构（CommunityToolkit.Mvvm 风格的手动实现）
- 公共 API 需文档注释
- 异常捕获处理，用户友好提示
- 命名语义化：变量名词、函数动宾、类名词短语
- 提交遵循 Conventional Commits 中文版

## UI 设计规范

- 暗色主题（GitHub 风格）
- 主背景：#0d1117，卡片背景：#161b22
- 主色调：绿色 #238636（Primary），蓝色 #58a6ff（Accent）
- 布局：侧边栏导航 + 顶部标题栏 + 卡片式内容区
- 圆角：按钮/卡片 6-8px
- 间距：内边距 16px，卡片间距 12px
