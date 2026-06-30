param(
    [string]$Subject = "CN=FastGithub",
    [string]$Password = "",
    [int]$ValidYears = 10,
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrEmpty($OutputPath)) {
    $OutputPath = Join-Path $Root "scripts\FastGithub.pfx"
}

if ([string]::IsNullOrEmpty($Password)) {
    $securePwd = Read-Host "Please enter certificate password" -AsSecureString
}
else {
    $securePwd = ConvertTo-SecureString $Password -AsPlainText -Force
}

Write-Host "==> Generating self-signed code signing certificate..." -ForegroundColor Cyan
Write-Host "    Subject: $Subject"
Write-Host "    Valid for: $ValidYears years"
Write-Host "    Output: $OutputPath"

$cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $Subject -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddYears($ValidYears) -FriendlyName "FastGithub Code Signing"

if (-not $cert) {
    Write-Error "Failed to generate certificate"
    exit 1
}

Write-Host ""
Write-Host "==> Exporting certificate to .pfx file..." -ForegroundColor Cyan
Export-PfxCertificate -Cert $cert -FilePath $OutputPath -Password $securePwd | Out-Null

Write-Host ""
Write-Host "==> Certificate generated successfully!" -ForegroundColor Green
Write-Host "    Thumbprint: $($cert.Thumbprint)"
Write-Host "    Path: $OutputPath"

Write-Host ""
Write-Host "==> Next steps:" -ForegroundColor Yellow
Write-Host "    1. Double-click the .pfx file and install to Trusted Root Certification Authorities (Local Machine)"
Write-Host "    2. Or run PowerShell as Administrator:"
Write-Host "       Import-PfxCertificate -FilePath `"$OutputPath`" -CertStoreLocation Cert:\LocalMachine\Root -Password (ConvertTo-SecureString 'YourPassword' -AsPlainText -Force)"
Write-Host "    3. Then re-run publish script with signing enabled"
