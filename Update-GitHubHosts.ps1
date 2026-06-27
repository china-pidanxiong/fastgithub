# ============================================================
# GitHub Hosts Auto-Update Script (PowerShell) - Enhanced Version
# Features:
#   - Resolve domains using public DNS (bypass hosts)
#   - Check HTTPS (port 443) availability before selecting IP
#   - Choose fastest available IP by ping latency
#   - Retry logic for file I/O to avoid locking issues
#   - Auto backup and DNS flush
#   - Structured hosts entry management with markers
#   - Persistent logging
#   - Parameterized execution (DryRun, Clean, etc.)
#   - Old backup auto-cleanup
#   - Comprehensive error handling
# Usage: Run as Administrator
# ============================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$DryRun = $false,

    [Parameter(Mandatory = $false)]
    [switch]$Clean = $false,

    [Parameter(Mandatory = $false)]
    [string]$ConfigPath = "",

    [Parameter(Mandatory = $false)]
    [string]$LogPath = "",

    [Parameter(Mandatory = $false)]
    [int]$MaxBackupCount = 10,

    [Parameter(Mandatory = $false)]
    [int]$TimeoutMs = 3000
)

# -------------------- Configuration --------------------
$script:Config = @{
    Domains = @(
        "github.com",
        "www.github.com",
        "api.github.com",
        "raw.githubusercontent.com",
        "codeload.github.com",
        "objects.githubusercontent.com",
        "gist.github.com",
        "gist.githubusercontent.com",
        "cloud.githubusercontent.com",
        "user-images.githubusercontent.com",
        "avatars.githubusercontent.com",
        "avatars0.githubusercontent.com",
        "avatars1.githubusercontent.com",
        "avatars2.githubusercontent.com",
        "avatars3.githubusercontent.com",
        "avatars4.githubusercontent.com",
        "avatars5.githubusercontent.com",
        "avatars6.githubusercontent.com",
        "avatars7.githubusercontent.com",
        "github.io",
        "pkg.github.com",
        "ghcr.io",
        "github.community"
    )
    DnsServers = @("114.114.114.114", "119.29.29.29", "223.5.5.5", "8.8.8.8", "1.1.1.1")
    HostsPath = "$env:windir\System32\drivers\etc\hosts"
    BackupDir = "$env:windir\System32\drivers\etc"
    HostsMarkerStart = "# === GitHub Hosts Start (Managed by Update-GitHubHosts) ==="
    HostsMarkerEnd   = "# === GitHub Hosts End (Managed by Update-GitHubHosts) ==="
}

$script:LogFile = if ($LogPath) { $LogPath } else { "$PSScriptRoot\github-hosts-update.log" }
# -------------------------------------------------------

# ==================== Logging System ====================
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS")]
        [string]$Level = "INFO",

        [Parameter(Mandatory = $false)]
        [switch]$NoConsole = $false
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    if (-not $NoConsole) {
        $colorMap = @{
            "INFO"    = "White"
            "WARN"    = "Yellow"
            "ERROR"   = "Red"
            "SUCCESS" = "Green"
        }
        Write-Host $logEntry -ForegroundColor $colorMap[$Level]
    }

    try {
        Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8 -ErrorAction Stop
    }
    catch {
        Write-Host "WARNING: Failed to write log: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ==================== Admin Check ====================
function Test-AdminRights {
    $currentPrincipal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ==================== Configuration Loader ====================
function Import-Config {
    if (-not $ConfigPath) { return }
    if (-not (Test-Path $ConfigPath)) {
        Write-Log -Message "Config file not found: $ConfigPath, using defaults" -Level "WARN"
        return
    }

    try {
        $userConfig = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($userConfig.Domains -and $userConfig.Domains -is [array]) {
            $script:Config.Domains = $userConfig.Domains
            Write-Log -Message "Loaded $($userConfig.Domains.Count) domains from config" -Level "INFO"
        }
        if ($userConfig.DnsServers -and $userConfig.DnsServers -is [array]) {
            $script:Config.DnsServers = $userConfig.DnsServers
        }
        if ($userConfig.HostsPath) {
            $script:Config.HostsPath = $userConfig.HostsPath
        }
    }
    catch {
        Write-Log -Message "Failed to parse config: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

# ==================== Backup Management ====================
function New-HostsBackup {
    [CmdletBinding()]
    param()

    $timestamp = Get-Date -Format "yyyyMMddHHmmss"
    $backupPath = Join-Path $script:Config.BackupDir "hosts.githubbak.$timestamp"
    $backupDone = $false

    for ($i = 0; $i -lt 5; $i++) {
        try {
            Copy-Item -Path $script:Config.HostsPath -Destination $backupPath -ErrorAction Stop
            Write-Log -Message "Backup created: $backupPath" -Level "SUCCESS"
            $backupDone = $true
            break
        }
        catch {
            Write-Log -Message "Backup attempt $($i+1) failed: $($_.Exception.Message)" -Level "WARN"
            Start-Sleep -Milliseconds 500
        }
    }

    if (-not $backupDone) {
        Write-Log -Message "WARNING: Cannot backup hosts file, will continue anyway." -Level "ERROR"
    }

    return $backupDone
}

function Remove-OldBackups {
    [CmdletBinding()]
    param()

    if ($MaxBackupCount -le 0) { return }

    try {
        $backups = Get-ChildItem -Path $script:Config.BackupDir -Filter "hosts.githubbak.*" -File |
                   Sort-Object CreationTime -Descending

        if ($backups.Count -gt $MaxBackupCount) {
            $toRemove = $backups | Select-Object -Skip $MaxBackupCount
            foreach ($bak in $toRemove) {
                try {
                    Remove-Item $bak.FullName -Force -ErrorAction Stop
                    Write-Log -Message "Removed old backup: $($bak.Name)" -Level "INFO"
                }
                catch {
                    Write-Log -Message "Failed to remove old backup $($bak.Name): $($_.Exception.Message)" -Level "WARN"
                }
            }
        }
    }
    catch {
        Write-Log -Message "Cleanup old backups failed: $($_.Exception.Message)" -Level "WARN"
    }
}

# ==================== File I/O with Retry ====================
function Read-HostsFile {
    [CmdletBinding()]
    param()

    for ($i = 0; $i -lt 5; $i++) {
        try {
            $content = [System.IO.File]::ReadAllText($script:Config.HostsPath, [System.Text.Encoding]::UTF8)
            return $content
        }
        catch {
            Write-Log -Message "Read attempt $($i+1) failed: $($_.Exception.Message)" -Level "WARN"
            Start-Sleep -Milliseconds 500
        }
    }
    throw "Cannot read hosts file after 5 attempts."
}

function Write-HostsFile {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Content)

    for ($i = 0; $i -lt 5; $i++) {
        try {
            [System.IO.File]::WriteAllText($script:Config.HostsPath, $Content, [System.Text.Encoding]::UTF8)
            return
        }
        catch {
            Write-Log -Message "Write attempt $($i+1) failed: $($_.Exception.Message)" -Level "WARN"
            Start-Sleep -Milliseconds 500
        }
    }
    throw "Cannot write hosts file after 5 attempts."
}

# ==================== DNS Resolution (bypass hosts) ====================
function Test-ValidIP {
    param([string]$IP)
    $parsed = $null
    return [System.Net.IPAddress]::TryParse($IP, [ref]$parsed) -and $parsed.AddressFamily -eq 'InterNetwork'
}

function Get-DomainIPs {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Domain)

    foreach ($dns in $script:Config.DnsServers) {
        try {
            Write-Log -Message "  Trying DNS $dns ..." -Level "INFO" -NoConsole
            $records = Resolve-DnsName -Name $Domain -Type A -Server $dns -ErrorAction Stop |
                       Where-Object { $_.Type -eq 'A' -and $_.IPAddress -and (Test-ValidIP $_.IPAddress) }
            $ips = $records | Select-Object -ExpandProperty IPAddress -ErrorAction SilentlyContinue
            if ($ips -and $ips.Count -gt 0) {
                Write-Log -Message "  DNS $dns returned $($ips.Count) IP(s) for $Domain" -Level "INFO"
                return $ips
            }
        }
        catch {
            Write-Log -Message "  DNS $dns failed: $($_.Exception.Message)" -Level "WARN" -NoConsole
        }
    }

    Write-Log -Message "  Fallback to system DNS (may be affected by hosts)" -Level "WARN"
    try {
        $records = Resolve-DnsName -Name $Domain -Type A -ErrorAction Stop |
                   Where-Object { $_.Type -eq 'A' -and $_.IPAddress -and (Test-ValidIP $_.IPAddress) }
        $ips = $records | Select-Object -ExpandProperty IPAddress -ErrorAction SilentlyContinue
        if ($ips) { return $ips }
    }
    catch {
        Write-Log -Message "  System DNS also failed: $($_.Exception.Message)" -Level "ERROR"
    }
    return $null
}

# ==================== Port & Latency Tests ====================
function Test-Port443 {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$IP)

    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectTask = $tcpClient.ConnectAsync($IP, 443)
        if ($connectTask.Wait($TimeoutMs)) {
            $tcpClient.Close()
            return $true
        }
        $tcpClient.Close()
    }
    catch {}
    return $false
}

function Test-PingLatency {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$IP)

    try {
        $ping = [System.Net.NetworkInformation.Ping]::new()
        $reply = $ping.Send($IP, $TimeoutMs)
        if ($reply -and $reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
            return $reply.RoundtripTime
        }
    }
    catch {}
    return $null
}

# ==================== Find Fastest Available IP ====================
function Get-FastestIP {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Domain)

    Write-Log -Message "Resolving $Domain ..." -Level "INFO"
    $ips = Get-DomainIPs $Domain
    if (-not $ips -or $ips.Count -eq 0) {
        Write-Log -Message "  Failed to resolve $domain" -Level "ERROR"
        return $null
    }

    Write-Log -Message "  Found $($ips.Count) IP(s), checking HTTPS (port 443) ..." -Level "INFO"
    $validIPs = @()
    foreach ($ip in $ips) {
        Write-Host "    Testing $ip :443 ... " -NoNewline
        $portOpen = Test-Port443 $ip
        if ($portOpen) {
            Write-Host "OK" -ForegroundColor Green
            $validIPs += $ip
        } else {
            Write-Host "BLOCKED/TIMEOUT" -ForegroundColor Red
        }
    }

    if ($validIPs.Count -eq 0) {
        Write-Log -Message "  No IP can reach GitHub via HTTPS! Using first resolved IP as last resort." -Level "ERROR"
        $first = $ips[0]
        Write-Log -Message "  Forced to use: $first (may not work)" -Level "WARN"
        return $first
    }

    Write-Log -Message "  $($validIPs.Count) valid IP(s), measuring latency ..." -Level "INFO"
    $fastestIP = $null
    $minTime = [int]::MaxValue

    foreach ($ip in $validIPs) {
        Write-Host "    Pinging $ip ... " -NoNewline
        $latency = Test-PingLatency $ip
        if ($latency -ne $null -and $latency -lt $minTime) {
            $minTime = $latency
            $fastestIP = $ip
            Write-Host "${latency}ms (best)" -ForegroundColor Green
        }
        elseif ($latency -ne $null) {
            Write-Host "${latency}ms" -ForegroundColor White
        }
        else {
            Write-Host "timeout" -ForegroundColor Yellow
        }
    }

    if ($fastestIP) {
        Write-Log -Message "  Best IP for $Domain : $fastestIP (${minTime}ms, HTTPS OK)" -Level "SUCCESS"
        return $fastestIP
    }
    else {
        Write-Log -Message "  All ping timed out but ports open; using first valid: $($validIPs[0])" -Level "WARN"
        return $validIPs[0]
    }
}

# ==================== Hosts Entry Management (Marker-based) ====================
function Update-ManagedHostsEntries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Entries
    )

    Write-Log -Message "Updating managed hosts entries..." -Level "INFO"
    $content = Read-HostsFile

    $startMarker = $script:Config.HostsMarkerStart
    $endMarker = $script:Config.HostsMarkerEnd

    $entryLines = @()
    foreach ($domain in $Entries.Keys) {
        $ip = $Entries[$domain]
        if ($ip) {
            $entryLines += "$ip $domain"
        }
    }
    $newBlock = "$startMarker`n$($entryLines -join "`n")`n$endMarker"

    $startIndex = $content.IndexOf($startMarker)

    if ($startIndex -ge 0) {
        Write-Log -Message "Found existing managed block, replacing..." -Level "INFO"
        $endIndex = $content.IndexOf($endMarker, $startIndex)
        if ($endIndex -ge 0) {
            $endIndex += $endMarker.Length
            $newContent = $content.Substring(0, $startIndex) + $newBlock + $content.Substring($endIndex)
        } else {
            $newContent = $content.Substring(0, $startIndex) + $newBlock + "`n"
        }
    }
    else {
        Write-Log -Message "No existing managed block, appending..." -Level "INFO"
        if (-not $content.EndsWith("`n")) {
            $content += "`n"
        }
        $newContent = $content + "`n$newBlock`n"
    }

    if ($DryRun) {
        Write-Log -Message "[DRY-RUN] Would update hosts file with $($Entries.Count) entries" -Level "WARN"
        Write-Host "`n--- Preview of managed hosts block ---" -ForegroundColor Cyan
        Write-Host $newBlock -ForegroundColor Cyan
        Write-Host "--- End Preview ---`n" -ForegroundColor Cyan
        return $true
    }

    try {
        Write-HostsFile $newContent
        Write-Log -Message "Successfully updated $($Entries.Count) hosts entries" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log -Message "Failed to write hosts file: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Clear-ManagedHostsEntries {
    [CmdletBinding()]
    param()

    Write-Log -Message "Cleaning managed hosts entries..." -Level "INFO"
    $content = Read-HostsFile

    $startMarker = $script:Config.HostsMarkerStart
    $endMarker = $script:Config.HostsMarkerEnd

    $startIndex = $content.IndexOf($startMarker)

    if ($startIndex -ge 0) {
        if ($DryRun) {
            Write-Log -Message "[DRY-RUN] Would remove managed hosts block" -Level "WARN"
            return $true
        }

        $endIndex = $content.IndexOf($endMarker, $startIndex)
        if ($endIndex -ge 0) {
            $endIndex += $endMarker.Length
            # 移除标记块及其前后多余的换行
            $removeStart = $startIndex
            if ($removeStart -gt 0 -and $content[$removeStart - 1] -eq "`n") {
                $removeStart--
            }
            $removeEnd = $endIndex
            if ($removeEnd -lt $content.Length -and $content[$removeEnd] -eq "`n") {
                $removeEnd++
            }
            $newContent = $content.Substring(0, $removeStart) + $content.Substring($removeEnd)
            $newContent = $newContent.TrimEnd() + "`n"
        } else {
            $newContent = $content.Substring(0, $startIndex).TrimEnd() + "`n"
        }

        try {
            Write-HostsFile $newContent
            Write-Log -Message "Managed hosts entries removed successfully" -Level "SUCCESS"
            return $true
        }
        catch {
            Write-Log -Message "Failed to clean hosts: $($_.Exception.Message)" -Level "ERROR"
            return $false
        }
    }
    else {
        Write-Log -Message "No managed entries found, nothing to clean" -Level "INFO"
        return $true
    }
}

# ==================== DNS Flush ====================
function Invoke-DnsFlush {
    [CmdletBinding()]
    param()

    Write-Log -Message "Flushing DNS cache..." -Level "INFO"
    try {
        $output = ipconfig /flushdns 2>&1
        Write-Log -Message "DNS cache flushed successfully" -Level "SUCCESS"
    }
    catch {
        Write-Log -Message "DNS flush warning: $($_.Exception.Message)" -Level "WARN"
    }
}

# ==================== Main Execution ====================
function Invoke-GitHubHostsUpdate {
    [CmdletBinding()]
    param()

    Write-Log -Message "========================================" -Level "INFO"
    Write-Log -Message "Starting GitHub hosts update process" -Level "INFO"
    Write-Log -Message "DryRun: $DryRun | MaxBackups: $MaxBackupCount | Timeout: ${TimeoutMs}ms" -Level "INFO"

    if (-not (Test-AdminRights)) {
        if ($DryRun) {
            Write-Log -Message "WARNING: Not running as Admin (DryRun mode - read-only preview)" -Level "WARN"
        } else {
            Write-Log -Message "ERROR: Administrator privileges required. Right-click PowerShell -> Run as administrator" -Level "ERROR"
            throw "Administrator privileges required"
        }
    } else {
        Write-Log -Message "Administrator privileges confirmed" -Level "SUCCESS"
    }

    try {
        Import-Config
    }
    catch {
        Write-Log -Message "Config import failed, aborting" -Level "ERROR"
        return 1
    }

    if ($Clean) {
        Write-Host ""
        Write-Log -Message "Clean mode: removing all managed hosts entries" -Level "WARN"
        if (-not $DryRun) { New-HostsBackup | Out-Null }
        Clear-ManagedHostsEntries
        if (-not $DryRun) { Invoke-DnsFlush }
        Write-Log -Message "Clean operation completed" -Level "SUCCESS"
        return 0
    }

    if (-not $DryRun) {
        New-HostsBackup | Out-Null
        Remove-OldBackups
    }

    $results = @{}
    $total = $script:Config.Domains.Count
    $current = 0

    Write-Host ""
    foreach ($domain in $script:Config.Domains) {
        $current++
        Write-Host "[$current/$total] $domain" -ForegroundColor Yellow
        try {
            $bestIP = Get-FastestIP $domain
            $results[$domain] = $bestIP
        }
        catch {
            Write-Log -Message "Error processing $domain : $($_.Exception.Message)" -Level "ERROR"
            $results[$domain] = $null
        }
        Write-Host ""
    }

    $successCount = ($results.GetEnumerator() | Where-Object { $_.Value }).Count
    Write-Log -Message "Resolved $successCount/$total domains successfully" -Level "INFO"

    if ($successCount -eq 0) {
        Write-Log -Message "ERROR: No domains resolved successfully. Aborting update." -Level "ERROR"
        return 1
    }

    Update-ManagedHostsEntries -Entries $results | Out-Null

    if (-not $DryRun) {
        Invoke-DnsFlush
    }

    Write-Log -Message "All done! $successCount/$total entries updated." -Level "SUCCESS"
    Write-Log -Message "Reopen your browser or run 'ping github.com' to test." -Level "INFO"
    Write-Log -Message "========================================" -Level "INFO"

    return 0
}

try {
    $exitCode = Invoke-GitHubHostsUpdate
    exit $exitCode
}
catch {
    Write-Log -Message "FATAL ERROR: $($_.Exception.Message)" -Level "ERROR"
    Write-Log -Message "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}
