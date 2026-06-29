# AGENTS.md - AI 代理项目指南

本文件供 AI 编程助手（Claude / Cursor / TRAE 等）快速了解项目结构和开发约定。

## 项目概览

**FastGithub** - GitHub Hosts 加速器，通过自动获取 GitHub 域名的最佳 IP 并写入系统 hosts 文件来加速访问。

- **主程序**：FastGithub.App.exe（WPF，.NET 9，FrameworkDependent 单文件）
- **引导器**：FastGithub.exe（WinForms，.NET Framework 4.8）
- **架构**：引导器检测 .NET 9 Desktop Runtime，缺失则自动安装，然后启动主程序

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
│   └── publish.ps1              # 发布脚本
├── docs/
│   ├── DEVELOPMENT.md           # 开发环境说明
│   └── PRODUCT.md               # 产品文档
└── FastGithub.sln
```

## 常用命令

```powershell
# 构建
.\.dotnet\dotnet.exe build src\FastGithub\FastGithub.csproj -c Release

# 测试
.\.dotnet\dotnet.exe test tests\FastGithub.Tests\FastGithub.Tests.csproj -c Release

# 打包发布
.\scripts\publish.ps1
```

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

详见 [DEVELOPMENT.md](DEVELOPMENT.md)。
