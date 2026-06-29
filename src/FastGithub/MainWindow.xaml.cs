using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
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

    private void NavListBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
    {
        if (DataContext is not MainWindowViewModel vm) return;
        ContentArea.Content = NavListBox.SelectedIndex switch
        {
            0 => new Views.DashboardView { DataContext = vm.Dashboard },
            1 => new Views.ConfigView { DataContext = vm.Config },
            2 => new Views.LogView { DataContext = vm.Log },
            _ => ContentArea.Content
        };
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
