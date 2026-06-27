using System.ComponentModel;
using System.Windows;
using FastGithub.Services;

namespace FastGithub;

/// <summary>主窗口：关闭按钮最小化到托盘而非退出。</summary>
public partial class MainWindow : Window
{
    private bool _hasMinimizedOnce;
    private TrayService? _trayService;

    public MainWindow() => InitializeComponent();

    public void SetTrayService(TrayService trayService) => _trayService = trayService;

    private void Window_Closing(object sender, CancelEventArgs e)
    {
        e.Cancel = true;
        Hide();
        if (!_hasMinimizedOnce)
        {
            _hasMinimizedOnce = true;
            _trayService?.ShowBalloon("GitHub Hosts", "程序在后台运行，双击托盘图标可恢复窗口");
        }
    }
}
