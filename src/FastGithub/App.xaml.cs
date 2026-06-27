using System.Diagnostics;
using System.IO;
using System.Windows;
using FastGithub.Core;
using FastGithub.Models;
using FastGithub.Services;
using FastGithub.ViewModels;
using Application = System.Windows.Application;
using MessageBox = System.Windows.MessageBox;

namespace FastGithub;

/// <summary>
/// 应用入口：UAC 提权检测 + 依赖注入。
/// </summary>
public partial class App : Application
{
    private TrayService? _trayService;
    private LogService? _logService;

    public static AppConfig Config { get; private set; } = AppConfig.CreateDefault();

    protected override void OnStartup(StartupEventArgs e)
    {
        if (!IsAdministrator())
        {
            RestartAsAdmin();
            Shutdown();
            return;
        }

        var configPath = Path.Combine(AppContext.BaseDirectory, "config.json");
        if (!File.Exists(configPath))
        {
            var examplePath = Path.Combine(AppContext.BaseDirectory, "config.example.json");
            if (File.Exists(examplePath)) File.Copy(examplePath, configPath);
        }
        var configService = new ConfigService(configPath);
        Config = configService.Load();

        var logPath = Path.Combine(AppContext.BaseDirectory, "github-hosts-update.log");
        _logService = new LogService(logPath);

        var dnsResolver = new DnsResolver();
        var networkTester = new NetworkTester(Config.TimeoutMs);
        var hostsFileMgr = new HostsFileManager(Config.HostsPath,
            "# === GitHub Hosts Start (Managed by FastGithub) ===",
            "# === GitHub Hosts End (Managed by FastGithub) ===");
        var updater = new HostsUpdater(dnsResolver, networkTester, hostsFileMgr,
            (level, msg) => _logService.Log(level, msg), Config.TimeoutMs);

        var logVm = new LogViewModel();
        var configVm = new ConfigViewModel(configService, onSaved: cfg => Config = cfg);
        _trayService = new TrayService(
            onRefresh: async () =>
            {
                try
                {
                    if (MainWindow?.DataContext is MainWindowViewModel mwVm)
                        await mwVm.Dashboard.RefreshAsync();
                }
                catch (Exception ex) { _logService.Error($"托盘刷新异常: {ex}"); }
            },
            onShowWindow: () => MainWindow?.Show());

        var dashboardVm = new DashboardViewModel(updater, _logService, logVm,
            () => Config, _trayService);

        var mwVm = new MainWindowViewModel(dashboardVm, configVm, logVm);
        var mainWindow = new MainWindow { DataContext = mwVm };
        mainWindow.SetTrayService(_trayService);
        MainWindow = mainWindow;
        mainWindow.Show();
        dashboardVm.Initialize();
    }

    private static bool IsAdministrator()
    {
        using var identity = System.Security.Principal.WindowsIdentity.GetCurrent();
        var principal = new System.Security.Principal.WindowsPrincipal(identity);
        return principal.IsInRole(System.Security.Principal.WindowsBuiltInRole.Administrator);
    }

    private static void RestartAsAdmin()
    {
        var exePath = Environment.ProcessPath!;
        var startInfo = new ProcessStartInfo
        {
            FileName = exePath,
            UseShellExecute = true,
            Verb = "runas"
        };
        try { Process.Start(startInfo); }
        catch { MessageBox.Show("需要管理员权限才能修改 hosts 文件。"); }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _trayService?.Dispose();
        _logService?.Dispose();
        base.OnExit(e);
    }
}
