# ============================================================
# GitHub Hosts Local HTTP Server
# Provides REST API for browser extension to trigger hosts update
# Usage: Run as Administrator
# ============================================================

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [int]$Port = 17890,

    [Parameter(Mandatory = $false)]
    [string]$UpdateScriptPath = ""
)

$ErrorActionPreference = "Stop"

$script:ScriptRoot = $PSScriptRoot
$script:UpdateScript = if ($UpdateScriptPath) { $UpdateScriptPath } else { Join-Path $script:ScriptRoot "Update-GitHubHosts.ps1" }
$script:LogFile = Join-Path $script:ScriptRoot "github-hosts-server.log"

# State managed via a simple file to avoid cross-thread issues
$script:StateFile = Join-Path $env:TEMP "github-hosts-server-state.json"
$script:OutputFile = Join-Path $env:TEMP "github-hosts-update-output.log"

function Write-ServerLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARN", "ERROR", "SUCCESS", "DEBUG")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    $colorMap = @{
        "INFO"    = "White"
        "WARN"    = "Yellow"
        "ERROR"   = "Red"
        "SUCCESS" = "Green"
        "DEBUG"   = "Gray"
    }
    Write-Host $logEntry -ForegroundColor $colorMap[$Level]

    try {
        Add-Content -Path $script:LogFile -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Test-AdminRights {
    $currentPrincipal = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Save-State {
    param(
        [bool]$IsRunning,
        $LastRun,
        $LastResult,
        [string]$LastError,
        $ProcessId = $null
    )
    $state = @{
        isRunning  = $IsRunning
        lastRun    = if ($LastRun) { $LastRun.ToString("o") } else { $null }
        lastResult = $LastResult
        lastError  = $LastError
        processId  = $ProcessId
    }
    try {
        $state | ConvertTo-Json | Set-Content -Path $script:StateFile -Encoding UTF8 -Force
    } catch {
        Write-ServerLog -Message "Failed to save state: $($_.Exception.Message)" -Level "WARN"
    }
}

function Read-State {
    $defaultState = [PSCustomObject]@{
        isRunning  = $false
        lastRun    = $null
        lastResult = $null
        lastError  = $null
        processId  = $null
    }
    try {
        if (Test-Path $script:StateFile) {
            $content = Get-Content -Path $script:StateFile -Raw -Encoding UTF8
            $obj = $content | ConvertFrom-Json
            # Ensure all properties exist
            if (-not ($obj.PSObject.Properties.Name -contains 'processId')) {
                $obj | Add-Member -NotePropertyName 'processId' -NotePropertyValue $null
            }
            return $obj
        }
    } catch {}
    return $defaultState
}

function Read-OutputLog {
    try {
        if (Test-Path $script:OutputFile) {
            $lines = Get-Content -Path $script:OutputFile -Encoding UTF8 -ErrorAction SilentlyContinue
            if ($lines) { return @($lines) }
        }
    } catch {}
    return @()
}

function Invoke-AsyncUpdate {
    $state = Read-State
    if ($state.isRunning) {
        # Check if the process is still alive
        $pid_ = $state.processId
        $alive = $false
        if ($pid_) {
            $alive = [bool](Get-Process -Id $pid_ -ErrorAction SilentlyContinue)
        }
        if ($alive) {
            Write-ServerLog -Message "Update already in progress, skipping" -Level "WARN"
            return $false
        }
        # Process died, mark as not running
        Write-ServerLog -Message "Previous process gone, resetting state" -Level "WARN"
    }

    try {
        # Clear previous output
        if (Test-Path $script:OutputFile) {
            Remove-Item $script:OutputFile -Force -ErrorAction SilentlyContinue
        }

        Write-ServerLog -Message "Starting hosts update process..." -Level "INFO"

        # Start the update script in a hidden window, redirecting output to file
        $cmdLine = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script:UpdateScript`" *> `"$script:OutputFile`""
        $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $cmdLine -PassThru -WindowStyle Hidden

        # Save running state with PID
        $startTime = Get-Date
        $stateData = @{
            isRunning  = $true
            lastRun    = $startTime.ToString("o")
            lastResult = $null
            lastError  = ""
            processId  = $process.Id
        }
        $stateData | ConvertTo-Json | Set-Content -Path $script:StateFile -Encoding UTF8 -Force

        Write-ServerLog -Message "Started update process (PID: $($process.Id))" -Level "INFO"

        return $true
    }
    catch {
        Write-ServerLog -Message "Failed to start update process: $($_.Exception.Message)" -Level "ERROR"
        Save-State -IsRunning $false -LastRun (Get-Date) -LastResult $false -LastError $_.Exception.Message
        return $false
    }
}

function Update-StateFromProcess {
    # Check if the running process has exited and update state accordingly
    $state = Read-State
    if (-not $state.isRunning) { return }

    $pid_ = $state.processId
    if (-not $pid_) { return }

    $alive = [bool](Get-Process -Id $pid_ -ErrorAction SilentlyContinue)
    if ($alive) { return }

    # Process has exited, update state
    $output = @()
    if (Test-Path $script:OutputFile) {
        $output = Get-Content -Path $script:OutputFile -Encoding UTF8 -ErrorAction SilentlyContinue
    }

    # Check if output indicates success (look for "All done" in output)
    $success = $false
    if ($output) {
        $success = ($output | Where-Object { $_ -match "All done.*entries updated" }).Count -gt 0
    }

    $newState = @{
        isRunning  = $false
        lastRun    = $state.lastRun
        lastResult = $success
        lastError  = if (-not $success) { "Update process exited. Check output log." } else { "" }
    }
    $newState | ConvertTo-Json | Set-Content -Path $script:StateFile -Encoding UTF8 -Force

    Write-ServerLog -Message "Update process completed. Success: $success" -Level $(if ($success) { "SUCCESS" } else { "ERROR" })
}

function Get-CorsHeaders {
    return @{
        "Access-Control-Allow-Origin"  = "*"
        "Access-Control-Allow-Methods" = "GET, POST, OPTIONS"
        "Access-Control-Allow-Headers" = "Content-Type"
        "Cache-Control"                = "no-cache, no-store, must-revalidate"
    }
}

function Send-JsonResponse {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [int]$StatusCode = 200,
        $Data
    )

    $Response.StatusCode = $StatusCode
    $Response.ContentType = "application/json; charset=utf-8"

    $corsHeaders = Get-CorsHeaders
    foreach ($key in $corsHeaders.Keys) {
        try {
            $Response.Headers[$key] = $corsHeaders[$key]
        } catch {}
    }

    $json = $Data | ConvertTo-Json -Depth 10
    $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
    $Response.ContentLength64 = $buffer.Length
    try {
        $Response.OutputStream.Write($buffer, 0, $buffer.Length)
    } finally {
        $Response.OutputStream.Close()
    }
}

function Start-HttpServer {
    if (-not (Test-AdminRights)) {
        Write-ServerLog -Message "ERROR: Administrator privileges required" -Level "ERROR"
        throw "Administrator privileges required"
    }

    if (-not (Test-Path $script:UpdateScript)) {
        Write-ServerLog -Message "ERROR: Update script not found at $script:UpdateScript" -Level "ERROR"
        throw "Update script not found"
    }

    # Initialize state
    Save-State -IsRunning $false -LastRun $null -LastResult $null -LastError ""

    $listener = [System.Net.HttpListener]::new()
    $prefix = "http://localhost:$Port/"
    $listener.Prefixes.Add($prefix)

    try {
        $listener.Start()
        Write-ServerLog -Message "========================================" -Level "INFO"
        Write-ServerLog -Message "GitHub Hosts Server started" -Level "SUCCESS"
        Write-ServerLog -Message "URL: $prefix" -Level "INFO"
        Write-ServerLog -Message "Update script: $script:UpdateScript" -Level "INFO"
        Write-ServerLog -Message "Press Ctrl+C to stop" -Level "INFO"
        Write-ServerLog -Message "========================================" -Level "INFO"
        Write-Host ""

        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response

            # Check if update process has exited
            Update-StateFromProcess

            $path = $request.Url.AbsolutePath.TrimEnd('/')
            $method = $request.HttpMethod.ToUpper()

            Write-ServerLog -Message "$method $path" -Level "DEBUG"

            if ($method -eq "OPTIONS") {
                Send-JsonResponse -Response $response -StatusCode 200 -Data @{ status = "ok" }
                continue
            }

            switch ($path) {
                "" {
                    Send-JsonResponse -Response $response -Data @{
                        name      = "GitHub Hosts Update Server"
                        version   = "1.0.0"
                        status    = "running"
                        endpoints = @(
                            "GET  /health       - Health check"
                            "GET  /status       - Current update status"
                            "POST /update       - Trigger hosts update"
                            "GET  /last-result  - Last update result with logs"
                        )
                    }
                }
                "/health" {
                    Send-JsonResponse -Response $response -Data @{
                        status    = "ok"
                        timestamp = Get-Date -Format "o"
                    }
                }
                "/status" {
                    $state = Read-State
                    Send-JsonResponse -Response $response -Data @{
                        isRunning  = $state.isRunning
                        lastRun    = $state.lastRun
                        lastResult = $state.lastResult
                    }
                }
                "/last-result" {
                    $state = Read-State
                    $outputLog = Read-OutputLog
                    Send-JsonResponse -Response $response -Data @{
                        isRunning  = $state.isRunning
                        lastRun    = $state.lastRun
                        lastResult = $state.lastResult
                        lastError  = $state.lastError
                        outputLog  = $outputLog
                    }
                }
                "/update" {
                    if ($method -ne "POST") {
                        Send-JsonResponse -Response $response -StatusCode 405 -Data @{
                            success = $false
                            message = "Method not allowed. Use POST."
                        }
                        continue
                    }

                    $state = Read-State
                    if ($state.isRunning) {
                        Send-JsonResponse -Response $response -StatusCode 409 -Data @{
                            success = $false
                            message = "Update already in progress"
                        }
                        continue
                    }

                    $started = Invoke-AsyncUpdate
                    if ($started) {
                        Send-JsonResponse -Response $response -Data @{
                            success = $true
                            message = "Update started. Poll /status for progress."
                        }
                    } else {
                        Send-JsonResponse -Response $response -StatusCode 500 -Data @{
                            success = $false
                            message = "Failed to start update process"
                        }
                    }
                }
                default {
                    Send-JsonResponse -Response $response -StatusCode 404 -Data @{
                        success = $false
                        message = "Endpoint not found: $path"
                    }
                }
            }
        }
    }
    catch {
        if ($_.Exception -is [System.OperationCanceledException]) {
            Write-ServerLog -Message "Server stopped by user" -Level "INFO"
        } else {
            Write-ServerLog -Message "Server error: $($_.Exception.Message)" -Level "ERROR"
            throw
        }
    }
    finally {
        if ($listener) {
            try {
                $listener.Stop()
                $listener.Close()
            } catch {}
            Write-ServerLog -Message "Server stopped" -Level "INFO"
        }
    }
}

try {
    Start-HttpServer
}
catch {
    Write-ServerLog -Message "FATAL: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
