using System.Drawing;
using System.IO;
using System.Windows.Forms;
using Application = System.Windows.Application;

namespace FastGithub.Services;

public class TrayService : IDisposable
{
    private readonly NotifyIcon _notifyIcon;
    private readonly Action _onRefresh;
    private readonly Action _onShowWindow;

    public TrayService(Action onRefresh, Action onShowWindow)
    {
        _onRefresh = onRefresh;
        _onShowWindow = onShowWindow;
        _notifyIcon = new NotifyIcon
        {
            Text = "GitHub Hosts 加速器",
            Visible = true,
            Icon = CreateIcon()
        };
        _notifyIcon.DoubleClick += (_, _) => _onShowWindow();
        _notifyIcon.ContextMenuStrip = CreateMenu();
    }

    public void ShowBalloon(string title, string message, ToolTipIcon icon = ToolTipIcon.Info)
    {
        // NotifyIcon 不是线程安全的，调用方可能在后台线程触发刷新，
        // 这里统一把气泡调用切回 UI 线程。
        var dispatcher = System.Windows.Application.Current?.Dispatcher;
        if (dispatcher == null) return;
        dispatcher.Invoke(() => _notifyIcon.ShowBalloonTip(3000, title, message, icon));
    }

    private ContextMenuStrip CreateMenu()
    {
        var menu = new ContextMenuStrip();
        var itemRefresh = new ToolStripMenuItem("立即刷新");
        itemRefresh.Click += (_, _) => _onRefresh();
        menu.Items.Add(itemRefresh);
        menu.Items.Add(new ToolStripSeparator());
        var itemShow = new ToolStripMenuItem("显示主窗口");
        itemShow.Click += (_, _) => _onShowWindow();
        menu.Items.Add(itemShow);
        menu.Items.Add(new ToolStripSeparator());
        var itemExit = new ToolStripMenuItem("退出");
        itemExit.Click += (_, _) =>
        {
            _notifyIcon.Visible = false;
            Application.Current.Shutdown();
        };
        menu.Items.Add(itemExit);
        return menu;
    }

    private static Icon CreateIcon()
    {
        try
        {
            var iconPath = Path.Combine(AppContext.BaseDirectory, "Assets", "AppIcon.ico");
            if (File.Exists(iconPath))
                return new Icon(iconPath);
        }
        catch { }

        try
        {
            using var stream = Application.GetResourceStream(
                new Uri("pack://application:,,,/Assets/AppIcon.ico", UriKind.Absolute))?.Stream;
            if (stream != null)
                return new Icon(stream);
        }
        catch { }

        using var bmp = new Bitmap(32, 32);
        using var g = Graphics.FromImage(bmp);
        using var pen = new Pen(Color.White, 2);
        g.SmoothingMode = System.Drawing.Drawing2D.SmoothingMode.AntiAlias;
        g.FillEllipse(Brushes.ForestGreen, 0, 0, 32, 32);
        g.DrawEllipse(pen, 6, 6, 20, 20);
        g.DrawLine(pen, 16, 8, 16, 16);
        g.DrawLine(pen, 12, 16, 16, 12);
        g.DrawLine(pen, 20, 16, 16, 12);
        var hicon = bmp.GetHicon();
        return Icon.FromHandle(hicon);
    }

    public void Dispose()
    {
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
    }
}
