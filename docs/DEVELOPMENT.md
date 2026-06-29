# 开发环境

## 构建环境

- **.NET SDK**: 使用项目本地 `.dotnet/dotnet.exe`（.NET 9 SDK 9.0.315）
- **目标框架**:
  - 主程序 FastGithub.App: `net9.0-windows`（WPF + WinForms）
  - 引导器 FastGithub.Launcher: `net48`（WinForms）
- **运行时**: FrameworkDependent（非自包含，依赖系统安装的 .NET 9 Desktop Runtime）
- **部署方式**: 单文件发布（PublishSingleFile）

## 构建命令

使用项目本地 SDK：

```powershell
# 构建主程序
.\.dotnet\dotnet.exe build src\FastGithub\FastGithub.csproj -c Release

# 构建引导器
.\.dotnet\dotnet.exe build src\FastGithub.Launcher\FastGithub.Launcher.csproj -c Release
```

## 打包发布

```powershell
.\scripts\publish.ps1
```

输出目录：`publish/FastGithub/`

### 发布包结构

```
FastGithub/
├── FastGithub.exe          # 引导器（.NET Framework 4.8）
├── FastGithub.exe.config
├── FastGithub.App.exe      # 主程序（.NET 9，单文件）
├── config.example.json
└── Assets/
    └── AppIcon.ico
```

## 单元测试

```powershell
# 主程序测试
.\.dotnet\dotnet.exe test tests\FastGithub.Tests\FastGithub.Tests.csproj -c Release

# 引导器测试（可能受系统安全策略影响）
.\.dotnet\dotnet.exe test tests\FastGithub.Launcher.Tests\FastGithub.Launcher.Tests.csproj -c Release
```

## 图标生成

使用 Python 脚本生成多尺寸 ICO：

```powershell
python src\FastGithub.Tools\GenerateIcon\generate_icon.py src\FastGithub\Assets\AppIcon.ico
```

依赖：Pillow（`pip install Pillow`）

## 注意事项

- 不要使用系统 `dotnet` 命令，系统可能只安装了 Runtime 没有 SDK
- 始终使用项目本地 `.dotnet\dotnet.exe` 进行构建和发布
- Launcher 的单元测试在某些系统安全策略下可能无法加载，属于环境问题非代码问题
