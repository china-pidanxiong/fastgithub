# FastGithub Publish Script
# Usage:
#   .\scripts\publish.ps1
#   .\scripts\publish.ps1 -Sign -CertPath .\cert.pfx -CertPassword yourpassword
#   .\scripts\publish.ps1 -Sign -CertThumbprint thumbprint

param(
    [switch]$Sign = $false,
    [string]$CertPath = "",
    [string]$CertPassword = "",
    [string]$CertThumbprint = "",
    [string]$TimeStampUrl = "http://timestamp.digicert.com"
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Dotnet = Join-Path $Root ".dotnet\dotnet.exe"

if (!(Test-Path $Dotnet)) {
    Write-Error "Dotnet SDK not found: $Dotnet"
    exit 1
}

function Find-SignTool {
    $possiblePaths = @(
        "C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe",
        "C:\Program Files (x86)\Windows Kits\10\App Certification Kit\signtool.exe",
        "C:\Program Files\Microsoft SDKs\Windows\v7.1A\Bin\signtool.exe"
    )

    foreach ($path in $possiblePaths) {
        $found = Get-ChildItem $path -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
        if ($found) {
            return $found
        }
    }

    return $null
}

function Get-CodeSigningCert {
    if (-not [string]::IsNullOrEmpty($CertThumbprint)) {
        $cert = Get-ChildItem "Cert:\CurrentUser\My\$CertThumbprint" -ErrorAction SilentlyContinue
        if (-not $cert) {
            $cert = Get-ChildItem "Cert:\LocalMachine\My\$CertThumbprint" -ErrorAction SilentlyContinue
        }
        if ($cert) {
            return $cert
        }
        Write-Warning "Certificate with thumbprint $CertThumbprint not found"
        return $null
    }

    if (-not [string]::IsNullOrEmpty($CertPath)) {
        if (!(Test-Path $CertPath)) {
            Write-Warning "Certificate file not found: $CertPath"
            return $null
        }
        if ([string]::IsNullOrEmpty($CertPassword)) {
            $securePwd = Read-Host "Enter certificate password" -AsSecureString
        }
        else {
            $securePwd = ConvertTo-SecureString $CertPassword -AsPlainText -Force
        }
        $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertPath, $securePwd)
        return $cert
    }

    Write-Warning "No certificate path or thumbprint specified"
    return $null
}

function Invoke-CodeSign {
    param([string]$FilePath)

    if (-not $Sign) {
        return
    }

    $fileName = [System.IO.Path]::GetFileName($FilePath)
    Write-Host "    Signing: $fileName" -ForegroundColor Cyan

    $signtool = Find-SignTool
    if ($signtool) {
        $args = @("sign", "/fd", "SHA256", "/tr", $TimeStampUrl, "/td", "SHA256")

        if (-not [string]::IsNullOrEmpty($CertThumbprint)) {
            $args += "/sha1"
            $args += $CertThumbprint
        }
        elseif (-not [string]::IsNullOrEmpty($CertPath)) {
            $args += "/f"
            $args += $CertPath
            if (-not [string]::IsNullOrEmpty($CertPassword)) {
                $args += "/p"
                $args += $CertPassword
            }
        }
        else {
            Write-Warning "No certificate path or thumbprint specified, skipping"
            return
        }

        $args += $FilePath

        & $signtool @args
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "signtool failed: $fileName"
        }
        return
    }

    $cert = Get-CodeSigningCert
    if (-not $cert) {
        Write-Warning "Failed to get certificate, skipping"
        return
    }

    try {
        $result = Set-AuthenticodeSignature -FilePath $FilePath -Certificate $cert -HashAlgorithm SHA256 -TimestampServer $TimeStampUrl
        if ($result.Status -eq "Valid") {
            Write-Host "    Signed: $fileName" -ForegroundColor Green
        }
        else {
            Write-Warning "Sign failed: $fileName - $($result.StatusMessage)"
        }
    }
    catch {
        Write-Warning "Sign exception: $fileName - $($_.Exception.Message)"
    }
}

$Sln = Join-Path $Root "FastGithub.sln"
$PublishDir = Join-Path $Root "publish"

Write-Host "==> Cleaning old publish directory..." -ForegroundColor Cyan
if (Test-Path $PublishDir) {
    Remove-Item $PublishDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $PublishDir | Out-Null

$FinalDir = Join-Path $PublishDir "FastGithub"
New-Item -ItemType Directory -Force -Path $FinalDir | Out-Null

Write-Host "`n==> Publishing main app (FastGithub.App, net9.0-windows, FrameworkDependent)..." -ForegroundColor Cyan
& $Dotnet publish (Join-Path $Root "src\FastGithub\FastGithub.csproj") `
    -c Release `
    -r win-x64 `
    --self-contained false `
    -o $FinalDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "Main app publish failed"
    exit 1
}

Write-Host "`n==> Building launcher (FastGithub.Launcher, net48)..." -ForegroundColor Cyan
$LauncherBuildDir = Join-Path $PublishDir "LauncherTemp"
& $Dotnet build (Join-Path $Root "src\FastGithub.Launcher\FastGithub.Launcher.csproj") `
    -c Release `
    -o $LauncherBuildDir

if ($LASTEXITCODE -ne 0) {
    Write-Error "Launcher build failed"
    exit 1
}

Write-Host "`n==> Copying launcher..." -ForegroundColor Cyan
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

if ($Sign) {
    Write-Host "`n==> Code signing..." -ForegroundColor Cyan
    $exes = Get-ChildItem $FinalDir -Filter "*.exe" -File
    foreach ($exe in $exes) {
        Invoke-CodeSign -FilePath $exe.FullName
    }

    $dlls = Get-ChildItem $FinalDir -Filter "*.dll" -File
    foreach ($dll in $dlls) {
        Invoke-CodeSign -FilePath $dll.FullName
    }
}

Write-Host "`n==> Running unit tests..." -ForegroundColor Cyan
& $Dotnet test (Join-Path $Root "tests\FastGithub.Tests\FastGithub.Tests.csproj") -c Release --no-build
$testExit = $LASTEXITCODE

Write-Host "`n==> Publish complete!" -ForegroundColor Green
Write-Host "Output directory: $FinalDir"
Write-Host ""
Get-ChildItem $FinalDir -File | Select-Object Name, @{Name='SizeKB';Expression={[math]::Round($_.Length/1KB,1)}} | Format-Table -AutoSize

$totalSize = (Get-ChildItem $FinalDir -Recurse -File | Measure-Object Length -Sum).Sum
Write-Host "`nTotal size: $([math]::Round($totalSize / 1MB, 2)) MB" -ForegroundColor Green

if ($testExit -ne 0) {
    Write-Warning "Unit tests failed, please check"
}
