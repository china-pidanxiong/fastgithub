using System.IO;
using System.Text.Json;
using FastGithub.Models;

namespace FastGithub.Services;

public class ConfigService
{
    private static readonly JsonSerializerOptions JsonOpts = new() { WriteIndented = true };
    private readonly string _path;

    public ConfigService(string path) => _path = path;

    /// <summary>
    /// 加载配置。文件缺失/损坏时回退默认；空字段用默认值补齐，避免后续空引用。
    /// </summary>
    public AppConfig Load()
    {
        if (!File.Exists(_path)) return AppConfig.CreateDefault();
        try
        {
            var json = File.ReadAllText(_path);
            var config = JsonSerializer.Deserialize<AppConfig>(json, JsonOpts);
            if (config == null) return AppConfig.CreateDefault();

            var def = AppConfig.CreateDefault();
            config.Domains = config.Domains.Count == 0 ? def.Domains : config.Domains;
            config.DnsServers = config.DnsServers.Count == 0 ? def.DnsServers : config.DnsServers;
            config.HostsPath = string.IsNullOrEmpty(config.HostsPath) ? def.HostsPath : config.HostsPath;
            config.MaxBackupCount = config.MaxBackupCount < 0 ? def.MaxBackupCount : config.MaxBackupCount;
            config.TimeoutMs = config.TimeoutMs <= 0 ? def.TimeoutMs : config.TimeoutMs;
            return config;
        }
        catch { return AppConfig.CreateDefault(); }
    }

    public void Save(AppConfig config)
    {
        var json = JsonSerializer.Serialize(config, JsonOpts);
        File.WriteAllText(_path, json);
    }
}
