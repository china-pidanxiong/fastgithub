using System.Collections.ObjectModel;
using System.IO;
using System.Windows.Input;
using FastGithub.Core;
using FastGithub.Models;
using FastGithub.Services;

namespace FastGithub.ViewModels;

public class DashboardViewModel : ViewModelBase
{
    private readonly HostsUpdater _updater;
    private readonly LogService _logService;
    private readonly LogViewModel _logVm;
    private readonly Func<AppConfig> _getConfig;
    private readonly TrayService _trayService;

    public ObservableCollection<HostsEntry> HostsEntries { get; } = new();

    private string _statusText = "就绪";
    public string StatusText { get => _statusText; set => SetProperty(ref _statusText, value); }

    private string _statusColor = "#656d76";
    public string StatusColor { get => _statusColor; set => SetProperty(ref _statusColor, value); }

    private double _progress;
    public double Progress { get => _progress; set => SetProperty(ref _progress, value); }

    private string _progressText = "";
    public string ProgressText { get => _progressText; set => SetProperty(ref _progressText, value); }

    private bool _isRefreshing;
    public bool IsRefreshing { get => _isRefreshing; set => SetProperty(ref _isRefreshing, value); }

    public ICommand RefreshCommand { get; }

    public DashboardViewModel(HostsUpdater updater, LogService logService, LogViewModel logVm,
        Func<AppConfig> getConfig, TrayService trayService)
    {
        _updater = updater;
        _logService = logService;
        _logVm = logVm;
        _getConfig = getConfig;
        _trayService = trayService;
        _updater.ProgressChanged += OnProgressChanged;
        _logService.OnLog += entry => _logVm.AddLog(entry);
        RefreshCommand = new RelayCommand(async _ => await RefreshAsync(), _ => !IsRefreshing);
    }

    private void OnProgressChanged(object? sender, UpdateProgress p)
    {
        System.Windows.Application.Current?.Dispatcher.Invoke(() =>
        {
            // 阶段细分回调（测试 443、Ping）传 completed=0/total=0，
            // 仅更新文字，不刷新进度条避免回退闪烁。
            if (p.Total > 0) Progress = p.Percent;
            ProgressText = $"[{p.Completed}/{p.Total}] {p.CurrentDomain} - {p.Stage}" +
                (p.CurrentIp != null ? $" ({p.CurrentIp})" : "") +
                (p.LatencyMs.HasValue ? $" {p.LatencyMs}ms" : "");
        });
    }

    public async Task RefreshAsync()
    {
        IsRefreshing = true;
        StatusText = "刷新中";
        StatusColor = "#9a6700";
        Progress = 0;
        HostsEntries.Clear();
        CommandManager.InvalidateRequerySuggested();

        try
        {
            var config = _getConfig();
            var result = await Task.Run(() => _updater.UpdateAsync(config));
            StatusText = $"完成 {result.Success}/{result.Total}";
            StatusColor = result.Success == result.Total ? "#1a7f37" : "#cf222e";
            _trayService.ShowBalloon("GitHub Hosts",
                result.Success == result.Total ? "刷新成功" : $"刷新完成（成功 {result.Success}/{result.Total}）");
            LoadEntriesFromHosts(result.Latencies);
        }
        catch (Exception ex)
        {
            StatusText = "失败";
            StatusColor = "#cf222e";
            _logService.Error($"刷新异常: {ex}");
            _trayService.ShowBalloon("GitHub Hosts", "刷新失败: " + ex.Message, ToolTipIcon.Error);
        }
        finally
        {
            IsRefreshing = false;
            CommandManager.InvalidateRequerySuggested();
        }
    }

    /// <summary>
    /// 从 hosts 文件加载条目到表格。latencies 非空时把本次刷新得到的延迟回写到条目。
    /// </summary>
    private void LoadEntriesFromHosts(Dictionary<string, long>? latencies = null)
    {
        var config = _getConfig();
        var content = File.Exists(config.HostsPath) ? File.ReadAllText(config.HostsPath) : "";
        HostsEntries.Clear();
        foreach (var domain in config.Domains)
        {
            var entry = new HostsEntry { Domain = domain, Status = "未在 hosts 中" };
            var line = content.Split('\n').FirstOrDefault(l =>
            {
                var tokens = l.Trim().Split(new[] { ' ', '\t' }, StringSplitOptions.RemoveEmptyEntries);
                return tokens.Length >= 2 && tokens[^1] == domain && !l.StartsWith("#");
            });
            if (line != null)
            {
                var parts = line.Trim().Split(new[] { ' ', '\t' }, 2);
                if (parts.Length >= 2)
                {
                    entry.Ip = parts[0];
                    entry.Status = "已配置";
                    entry.LastUpdate = DateTime.Now;
                }
            }
            if (latencies != null && latencies.TryGetValue(domain, out var lat))
                entry.LatencyMs = lat;
            HostsEntries.Add(entry);
        }
    }

    public void Initialize() => LoadEntriesFromHosts(null);
}

/// <summary>简单 ICommand 实现，订阅 CommandManager 让 CanExecute 自动重算。</summary>
public class RelayCommand : ICommand
{
    private readonly Action<object?> _execute;
    private readonly Func<object?, bool>? _canExecute;

    public RelayCommand(Action<object?> execute, Func<object?, bool>? canExecute = null)
    {
        _execute = execute;
        _canExecute = canExecute;
    }

    public bool CanExecute(object? parameter) => _canExecute?.Invoke(parameter) ?? true;
    public void Execute(object? parameter) => _execute(parameter);
    public event EventHandler? CanExecuteChanged
    {
        add { CommandManager.RequerySuggested += value; }
        remove { CommandManager.RequerySuggested -= value; }
    }
}
