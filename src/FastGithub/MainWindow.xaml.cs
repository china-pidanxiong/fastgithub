using System.ComponentModel;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using FastGithub.Services;
using FastGithub.ViewModels;
using MessageBox = System.Windows.MessageBox;

namespace FastGithub;

/// <summary>主窗口：关闭行为可配置（最小化到托盘或直接退出）。</summary>
public partial class MainWindow : Window
{
    private bool _hasMinimizedOnce;
    private TrayService? _trayService;
    private bool _shutdownConfirmed;

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

    private void NavListBox_PreviewMouseWheel(object sender, MouseWheelEventArgs e)
    {
        if (!e.Handled && ContentArea.Content is UIElement element)
        {
            e.Handled = true;
            var args = new MouseWheelEventArgs(e.MouseDevice, e.Timestamp, e.Delta)
            {
                RoutedEvent = UIElement.MouseWheelEvent
            };
            element.RaiseEvent(args);
        }
    }

    private void Window_Closing(object sender, CancelEventArgs e)
    {
        if (_shutdownConfirmed) return;

        var config = App.Config;

        if (config.RememberCloseChoice)
        {
            if (config.CloseToTray)
            {
                e.Cancel = true;
                Hide();
                if (!_hasMinimizedOnce)
                {
                    _hasMinimizedOnce = true;
                    _trayService?.ShowBalloon("GitHub Hosts", "程序在后台运行，双击托盘图标可恢复窗口");
                }
            }
            return;
        }

        e.Cancel = true;
        ShowCloseDialog();
    }

    private void ShowCloseDialog()
    {
        var result = MessageBox.Show(
            "选择关闭后的操作：\n\n是 = 最小化到托盘（后台运行）\n否 = 直接退出程序\n取消 = 取消关闭",
            "关闭提示",
            MessageBoxButton.YesNoCancel,
            MessageBoxImage.Question,
            MessageBoxResult.Yes);

        if (result == MessageBoxResult.Cancel) return;

        bool closeToTray = result == MessageBoxResult.Yes;

        var rememberResult = MessageBox.Show(
            "记住此选择，下次不再询问？",
            "记住选择",
            MessageBoxButton.YesNo,
            MessageBoxImage.Question);

        if (rememberResult == MessageBoxResult.Yes)
        {
            UpdateConfigAndSave(closeToTray, true);
        }
        else
        {
            App.Config.CloseToTray = closeToTray;
        }

        _shutdownConfirmed = !closeToTray;

        if (closeToTray)
        {
            Hide();
            if (!_hasMinimizedOnce)
            {
                _hasMinimizedOnce = true;
                _trayService?.ShowBalloon("GitHub Hosts", "程序在后台运行，双击托盘图标可恢复窗口");
            }
        }
        else
        {
            System.Windows.Application.Current.Shutdown();
        }
    }

    private void UpdateConfigAndSave(bool closeToTray, bool rememberChoice)
    {
        App.Config.CloseToTray = closeToTray;
        App.Config.RememberCloseChoice = rememberChoice;

        try
        {
            var configPath = Path.Combine(AppContext.BaseDirectory, "config.json");
            var configService = new ConfigService(configPath);
            configService.Save(App.Config);
        }
        catch { }
    }
}
