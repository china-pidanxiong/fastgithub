# FastGithub 发布脚本
# 依赖：项目本地 .NET 9 SDK（位于 .dotnet 目录）+ .NET Framework 4.8 构建工具
# 用法：.\scripts\publish.ps1

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Dotnet = Join-Path $Root ".dotnet\dotnet.exe"

if (!(Test-Path $Dotnet)) {
    Write-Error "未找到项目本地 .NET SDK: $Dotnet"
    exit 1
}

$Sln = Join-Path $Root "FastGithub.sln"
$PublishDir = Join-Path $Root "publish"

Write-Host "==> 清理旧的发布目录..." -ForegroundColor Cyan
if (Test-Path $PublishDir) {
    Remove-Item $PublishDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $PublishDir | Out-Null

$FinalDir = Join-Path $PublishDir "FastGithub"
New-Item -ItemType Directory -Force -Path $FinalDir | Out-Null

Write-Host "`n==> 发布主程序 (FastGithub.App, net9.0-windows, FrameworkDependent)..." -ForegroundColor Cyan
& $Dotnet publish (Join-Path $Root "src\FastGithub\FastGithub.csproj") `
    -c Release `
    -r win-x64 `
    --self-contained false `
    -o $FinalDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "主程序发布失败"
    exit 1
}

Write-Host "`n==> 构建引导器 (FastGithub.Launcher, net48)..." -ForegroundColor Cyan
$LauncherBuildDir = Join-Path $PublishDir "LauncherTemp"
& $Dotnet build (Join-Path $Root "src\FastGithub.Launcher\FastGithub.Launcher.csproj") `
    -c Release `
    -o $LauncherBuildDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "引导器构建失败"
    exit 1
}

Write-Host "`n==> 复制引导器..." -ForegroundColor Cyan
Copy-Item (Join-Path $LauncherBuildDir "FastGithub.exe") $FinalDir -Force
Copy-Item (Join-Path $LauncherBuildDir "FastGithub.exe.config") $FinalDir -Force -ErrorAction SilentlyContinue
if (Test-Path (Join-Path $LauncherBuildDir "Assets")) {
    if (!(Test-Path (Join-Path $FinalDir "Assets"))) {
        New-Item -ItemType Directory -Force -Path (Join-Path $FinalDir "Assets") | Out-Null
    }
    Copy-Item (Join-Path $LauncherBuildDir "Assets\*") (Join-Path $FinalDir "Assets\") -Recurse -Force
}

Copy-Item (Join-Path $Root "src\FastGithub\config.example.json") (Join-Path $FinalDir "config.example.json") -Force

Remove-Item $LauncherBuildDir -Recurse -Force

Write-Host "`n==> 运行单元测试..." -ForegroundColor Cyan
& $Dotnet test (Join-Path $Root "tests\FastGithub.Tests\FastGithub.Tests.csproj") -c Release --no-build
$testExit = $LASTEXITCODE

Write-Host "`n==> 发布完成！" -ForegroundColor Green
Write-Host "输出目录: $FinalDir"
Write-Host ""
Get-ChildItem $FinalDir -File | Select-Object Name, @{Name='SizeKB';Expression={[math]::Round($_.Length/1KB,1)}} | Format-Table -AutoSize

$totalSize = (Get-ChildItem $FinalDir -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host "`n总大小: $([math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor Green

if ($testExit -ne 0) {
    Write-Warning "单元测试未通过，请检查"
}
