# ============================================================
# GitHub Hosts Floating Widget (PowerShell + Windows Forms)
# Floating desktop widget for quick GitHub hosts refresh
# Usage: Right-click -> Run with PowerShell (Run as Administrator)
# ============================================================

#Requires -RunAsAdministrator

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$script:ScriptRoot = $PSScriptRoot
$script:UpdateScript = Join-Path $script:ScriptRoot "Update-GitHubHosts.ps1"
$script:IsUpdating = $false
$script:WidgetForm = $null
$script:NotifyIcon = $null
$script:dragOffsetX = 0
$script:dragOffsetY = 0

function Invoke-HostsUpdate {
    if ($script:IsUpdating) {
        [void][System.Windows.Forms.MessageBox]::Show(
            "Update in progress, please wait...",
            "Info",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information
        )
        return
    }

    $script:IsUpdating = $true
    Update-WidgetStatus -Status "Updating"

    $cmdLine = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script:UpdateScript`""
    $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $cmdLine -PassThru -WindowStyle Hidden

    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $timer.Add_Tick({
        if ($process.HasExited) {
            $timer.Stop()
            $timer.Dispose()
            $script:IsUpdating = $false

            if ($process.ExitCode -eq 0) {
                Update-WidgetStatus -Status "Success"
                Show-BalloonTip -Message "GitHub hosts updated successfully!" -Icon "Info"
            } else {
                Update-WidgetStatus -Status "Error"
                Show-BalloonTip -Message "GitHub hosts update failed. Check log for details." -Icon "Error"
            }

            Start-Sleep -Seconds 3
            if (-not $script:IsUpdating) {
                Update-WidgetStatus -Status "Ready"
            }
        }
    })
    $timer.Start()
}

function Update-WidgetStatus {
    param([string]$Status)

    if (-not $script:WidgetForm) { return }

    $label = $script:WidgetForm.Controls["lblStatus"]

    switch ($Status) {
        "Ready" {
            $label.Text = "Click to Refresh"
            $label.ForeColor = [System.Drawing.Color]::White
            $script:WidgetForm.BackColor = [System.Drawing.Color]::FromArgb(45, 164, 78)
        }
        "Updating" {
            $label.Text = "Updating..."
            $label.ForeColor = [System.Drawing.Color]::White
            $script:WidgetForm.BackColor = [System.Drawing.Color]::FromArgb(154, 103, 0)
        }
        "Success" {
            $label.Text = "Success!"
            $label.ForeColor = [System.Drawing.Color]::White
            $script:WidgetForm.BackColor = [System.Drawing.Color]::FromArgb(26, 127, 55)
        }
        "Error" {
            $label.Text = "Failed"
            $label.ForeColor = [System.Drawing.Color]::White
            $script:WidgetForm.BackColor = [System.Drawing.Color]::FromArgb(207, 34, 46)
        }
    }
}

function Show-BalloonTip {
    param(
        [string]$Message,
        [string]$Icon = "Info"
    )

    if ($script:NotifyIcon) {
        $iconMap = @{
            "Info"    = [System.Windows.Forms.ToolTipIcon]::Info
            "Warning" = [System.Windows.Forms.ToolTipIcon]::Warning
            "Error"   = [System.Windows.Forms.ToolTipIcon]::Error
        }
        $script:NotifyIcon.ShowBalloonTip(3000, "GitHub Hosts", $Message, $iconMap[$Icon])
    }
}

function New-FloatingWidget {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "GitHub Hosts"
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
    $form.ClientSize = New-Object System.Drawing.Size(120, 120)
    $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual

    $screen = [System.Windows.Forms.Screen]::PrimaryScreen
    $wa = $screen.WorkingArea
    $form.Left = [int]$wa.Width - 140
    $form.Top = [int]$wa.Height - 160

    $form.TopMost = $true
    $form.BackColor = [System.Drawing.Color]::FromArgb(45, 164, 78)
    $form.Opacity = 0.95
    $form.ShowInTaskbar = $false

    $roundedPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $diameter = 20
    $w = $form.ClientSize.Width
    $h = $form.ClientSize.Height

    $roundedPath.AddArc(0, 0, $diameter, $diameter, 180, 90)
    $roundedPath.AddArc($w - $diameter, 0, $diameter, $diameter, 270, 90)
    $roundedPath.AddArc($w - $diameter, $h - $diameter, $diameter, $diameter, 0, 90)
    $roundedPath.AddArc(0, $h - $diameter, $diameter, $diameter, 90, 90)
    $roundedPath.CloseFigure()
    $form.Region = New-Object System.Drawing.Region($roundedPath)

    $btnRefresh = New-Object System.Windows.Forms.Button
    $btnRefresh.Name = "btnRefresh"
    $btnRefresh.Location = New-Object System.Drawing.Point(35, 15)
    $btnRefresh.Size = New-Object System.Drawing.Size(50, 50)
    $btnRefresh.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $btnRefresh.FlatAppearance.BorderSize = 0
    $btnRefresh.BackColor = [System.Drawing.Color]::Transparent
    $btnRefresh.Cursor = [System.Windows.Forms.Cursors]::Hand

    $iconBmp = New-Object System.Drawing.Bitmap(40, 40)
    $g = [System.Drawing.Graphics]::FromImage($iconBmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $whitePen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)
    $g.DrawEllipse($whitePen, 6, 6, 28, 28)
    $g.DrawLine($whitePen, 20, 10, 20, 20)
    $g.DrawLine($whitePen, 14, 20, 20, 14)
    $g.DrawLine($whitePen, 26, 20, 20, 14)
    $g.Dispose()
    $btnRefresh.Image = $iconBmp
    $btnRefresh.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter

    $btnRefresh.Add_Click({
        Invoke-HostsUpdate
    })

    $lblStatus = New-Object System.Windows.Forms.Label
    $lblStatus.Name = "lblStatus"
    $lblStatus.Text = "Click to Refresh"
    $lblStatus.Font = New-Object System.Drawing.Font("Microsoft YaHei", 9, [System.Drawing.FontStyle]::Regular)
    $lblStatus.ForeColor = [System.Drawing.Color]::White
    $lblStatus.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $lblStatus.Location = New-Object System.Drawing.Point(0, 70)
    $lblStatus.Size = New-Object System.Drawing.Size(120, 25)
    $lblStatus.BackColor = [System.Drawing.Color]::Transparent

    $lblVersion = New-Object System.Windows.Forms.Label
    $lblVersion.Text = "v1.0"
    $lblVersion.Font = New-Object System.Drawing.Font("Microsoft YaHei", 7, [System.Drawing.FontStyle]::Regular)
    $lblVersion.ForeColor = [System.Drawing.Color]::FromArgb(200, 255, 200)
    $lblVersion.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $lblVersion.Location = New-Object System.Drawing.Point(0, 95)
    $lblVersion.Size = New-Object System.Drawing.Size(120, 20)
    $lblVersion.BackColor = [System.Drawing.Color]::Transparent

    [void]$form.Controls.Add($btnRefresh)
    [void]$form.Controls.Add($lblStatus)
    [void]$form.Controls.Add($lblVersion)

    $form.Add_MouseDown({
        param($sender, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $script:dragOffsetX = $e.X
            $script:dragOffsetY = $e.Y
        }
    })

    $form.Add_MouseMove({
        param($sender, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $mousePos = [System.Windows.Forms.Cursor]::Position
            $sender.Left = $mousePos.X - $script:dragOffsetX
            $sender.Top = $mousePos.Y - $script:dragOffsetY
        }
    })

    $form.Add_MouseUp({
        $script:dragOffsetX = 0
        $script:dragOffsetY = 0
    })

    $btnRefresh.Add_MouseDown({
        param($sender, $e)
        if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            $script:dragOffsetX = $e.X + $sender.Left
            $script:dragOffsetY = $e.Y + $sender.Top
        }
    })

    $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

    $menuRefresh = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuRefresh.Text = "Refresh Now"
    $menuRefresh.Add_Click({ Invoke-HostsUpdate })
    [void]$contextMenu.Items.Add($menuRefresh)

    [void]$contextMenu.Items.Add("-")

    $menuShowLog = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuShowLog.Text = "View Log"
    $menuShowLog.Add_Click({
        $logFile = Join-Path $script:ScriptRoot "github-hosts-update.log"
        if (Test-Path $logFile) {
            notepad.exe $logFile
        } else {
            [void][System.Windows.Forms.MessageBox]::Show(
                "Log file not found",
                "Info",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information
            )
        }
    })
    [void]$contextMenu.Items.Add($menuShowLog)

    $menuOpenHosts = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuOpenHosts.Text = "Open Hosts File"
    $menuOpenHosts.Add_Click({
        $hostsPath = "$env:windir\System32\drivers\etc\hosts"
        notepad.exe $hostsPath
    })
    [void]$contextMenu.Items.Add($menuOpenHosts)

    [void]$contextMenu.Items.Add("-")

    $menuTopMost = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuTopMost.Text = "Always on Top"
    $menuTopMost.Checked = $true
    $menuTopMost.Add_Click({
        $menuTopMost.Checked = -not $menuTopMost.Checked
        $form.TopMost = $menuTopMost.Checked
    })
    [void]$contextMenu.Items.Add($menuTopMost)

    $menuExit = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuExit.Text = "Exit"
    $menuExit.Add_Click({
        if ($script:NotifyIcon) {
            $script:NotifyIcon.Visible = $false
            $script:NotifyIcon.Dispose()
        }
        $form.Close()
        [System.Windows.Forms.Application]::Exit()
    })
    [void]$contextMenu.Items.Add($menuExit)

    $form.ContextMenuStrip = $contextMenu

    return $form
}

function New-TrayIcon {
    param([System.Windows.Forms.Form]$Form)

    $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $notifyIcon.Text = "GitHub Hosts Updater"
    $notifyIcon.Visible = $true

    $iconBmp = New-Object System.Drawing.Bitmap(32, 32)
    $g = [System.Drawing.Graphics]::FromImage($iconBmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.FillEllipse([System.Drawing.Brushes]::ForestGreen, 0, 0, 32, 32)
    $whitePen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 2)
    $g.DrawEllipse($whitePen, 6, 6, 20, 20)
    $g.DrawLine($whitePen, 16, 8, 16, 16)
    $g.DrawLine($whitePen, 12, 16, 16, 12)
    $g.DrawLine($whitePen, 20, 16, 16, 12)
    $g.Dispose()
    $notifyIcon.Icon = [System.Drawing.Icon]::FromHandle($iconBmp.GetHicon())

    $contextMenu = New-Object System.Windows.Forms.ContextMenuStrip

    $menuShow = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuShow.Text = "Show Widget"
    $menuShow.Add_Click({
        $Form.Visible = $true
    })
    [void]$contextMenu.Items.Add($menuShow)

    $menuHide = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuHide.Text = "Hide Widget"
    $menuHide.Add_Click({
        $Form.Visible = $false
    })
    [void]$contextMenu.Items.Add($menuHide)

    [void]$contextMenu.Items.Add("-")

    $menuRefresh2 = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuRefresh2.Text = "Refresh Now"
    $menuRefresh2.Add_Click({ Invoke-HostsUpdate })
    [void]$contextMenu.Items.Add($menuRefresh2)

    [void]$contextMenu.Items.Add("-")

    $menuExit2 = New-Object System.Windows.Forms.ToolStripMenuItem
    $menuExit2.Text = "Exit"
    $menuExit2.Add_Click({
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
        $Form.Close()
        [System.Windows.Forms.Application]::Exit()
    })
    [void]$contextMenu.Items.Add($menuExit2)

    $notifyIcon.ContextMenuStrip = $contextMenu

    $notifyIcon.Add_DoubleClick({
        $Form.Visible = -not $Form.Visible
    })

    return $notifyIcon
}

try {
    if (-not (Test-Path $script:UpdateScript)) {
        [void][System.Windows.Forms.MessageBox]::Show(
            "Update script not found: $script:UpdateScript",
            "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
        exit 1
    }

    $script:WidgetForm = New-FloatingWidget
    $script:NotifyIcon = New-TrayIcon -Form $script:WidgetForm

    Show-BalloonTip -Message "GitHub Hosts Widget started" -Icon "Info"

    [System.Windows.Forms.Application]::Run($script:WidgetForm)
}
catch {
    [void][System.Windows.Forms.MessageBox]::Show(
        "Startup failed: $($_.Exception.Message)",
        "Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error
    )
    exit 1
}
