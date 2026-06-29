using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using FastGithub.Services;
using FastGithub.ViewModels;

namespace FastGithub;

/// <summary>主窗口：关闭按钮最小化到托盘而非退出。</summary>
public partial class MainWindow : Window
{
    private bool _hasMinimizedOnce;
    private TrayService? _trayService;

    public MainWindow() => InitializeComponent();

    public void SetTrayService(TrayService trayService) => _trayService = trayService;

    private void Dashboard_Click(object sender, MouseButtonEventArgs e)
    {
        if (DataContext is MainWindowViewModel vm)
            ContentArea.Content = new Views.DashboardView { DataContext = vm.Dashboard };
    }

    private void Config_Click(object sender, MouseButtonEventArgs e)
    {
        if (DataContext is MainWindowViewModel vm)
            ContentArea.Content = new Views.ConfigView { DataContext = vm.Config };
    }

    private void Log_Click(object sender, MouseButtonEventArgs e)
    {
        if (DataContext is MainWindowViewModel vm)
            ContentArea.Content = new Views.LogView { DataContext = vm.Log };
    }

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
