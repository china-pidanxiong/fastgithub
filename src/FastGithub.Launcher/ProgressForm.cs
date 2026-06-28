using System;
using System.Windows.Forms;

namespace FastGithub.Launcher;

/// <summary>
/// 下载/安装阶段的进度窗口。无边框、可最小化、无关闭按钮，避免用户误中断流程。
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
        FormBorderStyle = FormBorderStyle.FixedToolWindow;
        MinimizeBox = true;
        MaximizeBox = false;
        ControlBox = false;
        Width = 400;
        Height = 120;
        StartPosition = FormStartPosition.CenterScreen;
        Text = "正在准备运行环境";

        _statusLabel = new Label
        {
            Width = 360,
            Height = 20,
            Top = 20,
            Left = 20,
            Text = "正在下载 .NET 9 Runtime..."
        };

        _progressBar = new ProgressBar
        {
            Width = 360,
            Height = 20,
            Top = 50,
            Left = 20,
            Minimum = 0,
            Maximum = 100,
            Value = 0
        };

        Controls.Add(_statusLabel);
        Controls.Add(_progressBar);
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
