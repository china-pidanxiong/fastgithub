using System.Collections.ObjectModel;
using System.Windows.Input;
using FastGithub.Models;
using FastGithub.Services;

namespace FastGithub.ViewModels;

public class ConfigViewModel : ViewModelBase
{
    private readonly ConfigService _configService;
    private readonly Action<AppConfig>? _onSaved;

    public ObservableCollection<string> Domains { get; } = new();
    public ObservableCollection<string> DnsServers { get; } = new();

    private string _hostsPath = "";
    public string HostsPath { get => _hostsPath; set => SetProperty(ref _hostsPath, value); }

    private int _maxBackupCount = 10;
    public int MaxBackupCount { get => _maxBackupCount; set => SetProperty(ref _maxBackupCount, value); }

    private int _timeoutMs = 3000;
    public int TimeoutMs { get => _timeoutMs; set => SetProperty(ref _timeoutMs, value); }

    private string? _selectedDomain;
    public string? SelectedDomain { get => _selectedDomain; set => SetProperty(ref _selectedDomain, value); }

    private string _newDomainInput = "";
    public string NewDomainInput { get => _newDomainInput; set => SetProperty(ref _newDomainInput, value); }

    private string? _selectedDnsServer;
    public string? SelectedDnsServer { get => _selectedDnsServer; set => SetProperty(ref _selectedDnsServer, value); }

    private string _newDnsServerInput = "";
    public string NewDnsServerInput { get => _newDnsServerInput; set => SetProperty(ref _newDnsServerInput, value); }

    public ICommand AddDomainCommand { get; }
    public ICommand RemoveDomainCommand { get; }
    public ICommand AddDnsServerCommand { get; }
    public ICommand RemoveDnsServerCommand { get; }

    public ConfigViewModel(ConfigService configService, Action<AppConfig>? onSaved = null)
    {
        _configService = configService;
        _onSaved = onSaved;
        Load(_configService.Load());

        AddDomainCommand = new RelayCommand(_ => AddDomain(), _ => !string.IsNullOrWhiteSpace(NewDomainInput));
        RemoveDomainCommand = new RelayCommand(_ => RemoveDomain(), _ => SelectedDomain != null);
        AddDnsServerCommand = new RelayCommand(_ => AddDnsServer(), _ => !string.IsNullOrWhiteSpace(NewDnsServerInput));
        RemoveDnsServerCommand = new RelayCommand(_ => RemoveDnsServer(), _ => SelectedDnsServer != null);
    }

    public void Load(AppConfig config)
    {
        Domains.Clear();
        foreach (var d in config.Domains) Domains.Add(d);
        DnsServers.Clear();
        foreach (var d in config.DnsServers) DnsServers.Add(d);
        HostsPath = config.HostsPath;
        MaxBackupCount = config.MaxBackupCount;
        TimeoutMs = config.TimeoutMs;
    }

    /// <summary>
    /// 保存配置并通知外部更新全局 Config，下次刷新立即生效（不必重启程序）。
    /// </summary>
    public void Save()
    {
        var config = new AppConfig
        {
            Domains = Domains.ToList(),
            DnsServers = DnsServers.ToList(),
            HostsPath = HostsPath,
            MaxBackupCount = MaxBackupCount,
            TimeoutMs = TimeoutMs
        };
        _configService.Save(config);
        _onSaved?.Invoke(config);
    }

    public void Reset() => Load(AppConfig.CreateDefault());

    public void AddDomain()
    {
        var v = (NewDomainInput ?? "").Trim();
        if (string.IsNullOrEmpty(v) || Domains.Contains(v)) { NewDomainInput = ""; return; }
        Domains.Add(v);
        NewDomainInput = "";
    }

    public void RemoveDomain()
    {
        if (SelectedDomain != null) Domains.Remove(SelectedDomain);
    }

    public void AddDnsServer()
    {
        var v = (NewDnsServerInput ?? "").Trim();
        if (string.IsNullOrEmpty(v) || DnsServers.Contains(v)) { NewDnsServerInput = ""; return; }
        DnsServers.Add(v);
        NewDnsServerInput = "";
    }

    public void RemoveDnsServer()
    {
        if (SelectedDnsServer != null) DnsServers.Remove(SelectedDnsServer);
    }
}
