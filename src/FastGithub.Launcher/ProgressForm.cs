using System;
using System.Drawing;
using System.IO;
using System.Windows.Forms;

namespace FastGithub.Launcher;

/// <summary>
/// 下载/安装阶段的进度窗口。暗色主题，可最小化，无关闭按钮，避免用户误中断流程。
/// </summary>
public partial class ProgressForm : Form
{
    private readonly ProgressBar _progressBar;
    private readonly Label _statusLabel;

    /// <summary>
    /// 构造进度窗口。
    /// </summary>
    public ProgressForm()
    {
        BackColor = Color.FromArgb(0x0d, 0x11, 0x17);
        ForeColor = Color.FromArgb(0xe6, 0xed, 0xf3);
        FormBorderStyle = FormBorderStyle.FixedToolWindow;
        MinimizeBox = true;
        MaximizeBox = false;
        ControlBox = false;
        Width = 440;
        Height = 140;
        StartPosition = FormStartPosition.CenterScreen;
        Text = "正在准备运行环境";
        Font = new Font("Segoe UI", 9f);

        try
        {
            var iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.ico");
            if (File.Exists(iconPath))
                Icon = new Icon(iconPath);
        }
        catch { }

        _statusLabel = new Label
        {
            Width = 400,
            Height = 24,
            Top = 24,
            Left = 20,
            ForeColor = Color.FromArgb(0xe6, 0xed, 0xf3),
            BackColor = Color.FromArgb(0x0d, 0x11, 0x17),
            Font = new Font("Segoe UI", 10f),
            Text = "正在下载 .NET 9 Runtime..."
        };

        _progressBar = new ProgressBar
        {
            Width = 400,
            Height = 24,
            Top = 60,
            Left = 20,
            Minimum = 0,
            Maximum = 100,
            Value = 0,
            Style = ProgressBarStyle.Continuous
        };

        var hintLabel = new Label
        {
            Width = 400,
            Height = 20,
            Top = 92,
            Left = 20,
            ForeColor = Color.FromArgb(0x7d, 0x85, 0x90),
            BackColor = Color.FromArgb(0x0d, 0x11, 0x17),
            Font = new Font("Segoe UI", 8.5f),
            Text = "安装完成后将自动启动 GitHub Hosts 加速器"
        };

        Controls.Add(_statusLabel);
        Controls.Add(_progressBar);
        Controls.Add(hintLabel);
    }

    /// <summary>
    /// 更新下载阶段进度百分比（线程安全，自动切回 UI 线程）。
    /// </summary>
    /// <param name="percent">0-100 百分比。</param>
    public void UpdateDownloadProgress(int percent)
    {
        if (IsDisposed) return;
        if (InvokeRequired)
            BeginInvoke((Action)(() => DoUpdateDownloadProgress(percent)));
        else
            DoUpdateDownloadProgress(percent);
    }

    private void DoUpdateDownloadProgress(int percent)
    {
        _progressBar.Style = ProgressBarStyle.Continuous;
        _progressBar.Value = Math.Max(0, Math.Min(100, percent));
        _statusLabel.Text = $"正在下载 .NET 9 Runtime... {percent}%";
    }

    /// <summary>
    /// 切换到安装阶段视图：进度条走满 + Marquee 动画 + 文字"正在安装..."（线程安全）。
    /// </summary>
    public void ShowInstallProgress()
    {
        if (IsDisposed) return;
        if (InvokeRequired)
            BeginInvoke((Action)DoShowInstallProgress);
        else
            DoShowInstallProgress();
    }

    private void DoShowInstallProgress()
    {
        _progressBar.Style = ProgressBarStyle.Marquee;
        _statusLabel.Text = "正在安装 .NET 9 Runtime，请稍候...";
    }

    /// <summary>
    /// 关闭进度窗口（线程安全）。
    /// </summary>
    public void CloseGracefully()
    {
        if (IsDisposed) return;
        if (InvokeRequired)
            BeginInvoke((Action)Close);
        else
            Close();
    }
}
