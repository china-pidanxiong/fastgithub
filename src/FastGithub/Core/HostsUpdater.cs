using System.IO;
using FastGithub.Models;

namespace FastGithub.Core;

/// <summary>
/// hosts 刷新编排器：DNS → 443 → Ping → 写 hosts → flushdns。
/// </summary>
public class HostsUpdater
{
    private readonly IDnsResolver _dnsResolver;
    private readonly INetworkTester _networkTester;
    private readonly HostsFileManager _hostsFileManager;
    private readonly Action<LogLevel, string> _log;
    private readonly int _timeoutMs;

    public event EventHandler<UpdateProgress>? ProgressChanged;

    public HostsUpdater(IDnsResolver dnsResolver, INetworkTester networkTester,
        HostsFileManager hostsFileManager, Action<LogLevel, string> log, int timeoutMs)
    {
        _dnsResolver = dnsResolver;
        _networkTester = networkTester;
        _hostsFileManager = hostsFileManager;
        _log = log;
        _timeoutMs = timeoutMs;
    }

    public async Task<UpdateResult> UpdateAsync(AppConfig config)
    {
        _log(LogLevel.Info, "开始刷新 GitHub hosts");
        var backupDir = Path.GetDirectoryName(config.HostsPath) ?? string.Empty;
        _hostsFileManager.Backup(backupDir);
        _hostsFileManager.RemoveOldBackups(backupDir, config.MaxBackupCount);

        var results = new Dictionary<string, string>();
        var latencies = new Dictionary<string, long>();
        var total = config.Domains.Count;
        var completed = 0;

        foreach (var domain in config.Domains)
        {
            OnProgress(domain, "解析 DNS", null, null, completed, total);
            var (bestIp, latency) = await GetFastestIpAsync(domain, config.DnsServers);
            if (bestIp != null)
            {
                results[domain] = bestIp;
                if (latency.HasValue) latencies[domain] = latency.Value;
            }
            completed++;
            OnProgress(domain, "完成", bestIp, latency, completed, total);
        }

        if (results.Count == 0)
        {
            _log(LogLevel.Error, "所有域名解析失败，终止更新");
            return new UpdateResult(0, total, latencies);
        }

        _hostsFileManager.UpdateManagedEntries(results);
        FlushDns();
        _log(LogLevel.Success, $"成功更新 {results.Count}/{total} 条 hosts 记录");
        return new UpdateResult(results.Count, total, latencies);
    }

    private async Task<(string? ip, long? latency)> GetFastestIpAsync(string domain, IReadOnlyList<string> dnsServers)
    {
        var ips = await _dnsResolver.ResolveAsync(domain, dnsServers, _timeoutMs);
        if (ips.Count == 0)
        {
            _log(LogLevel.Error, $"  {domain}: DNS 解析失败");
            return (null, null);
        }
        _log(LogLevel.Info, $"  {domain}: 解析到 {ips.Count} 个 IP");

        var validIps = new List<string>();
        foreach (var ip in ips)
        {
            OnProgress(domain, $"测试 443 {ip}", ip, null, 0, 0);
            if (await _networkTester.TestPort443Async(ip))
            {
                validIps.Add(ip);
                _log(LogLevel.Info, $"    {ip}:443 可用");
            }
            else _log(LogLevel.Warn, $"    {ip}:443 不可用");
        }

        if (validIps.Count == 0)
        {
            _log(LogLevel.Warn, $"  {domain}: 无可用 IP，回退到首个 IP {ips[0]}");
            return (ips[0], null);
        }

        var fastestIp = validIps[0];
        long minLatency = long.MaxValue;
        foreach (var ip in validIps)
        {
            OnProgress(domain, $"Ping {ip}", ip, null, 0, 0);
            var latency = await _networkTester.TestPingLatencyAsync(ip);
            if (latency.HasValue && latency.Value < minLatency)
            {
                minLatency = latency.Value;
                fastestIp = ip;
                _log(LogLevel.Success, $"    {ip}: {latency}ms (最优)");
            }
            else if (latency.HasValue) _log(LogLevel.Info, $"    {ip}: {latency}ms");
            else _log(LogLevel.Warn, $"    {ip}: Ping 超时");
        }
        return (fastestIp, minLatency == long.MaxValue ? null : minLatency);
    }

    private void FlushDns()
    {
        try
        {
            var psi = new System.Diagnostics.ProcessStartInfo
            {
                FileName = "ipconfig",
                Arguments = "/flushdns",
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true
            };
            System.Diagnostics.Process.Start(psi)?.WaitForExit(_timeoutMs * 3);
            _log(LogLevel.Info, "DNS 缓存已刷新");
        }
        catch (Exception ex) { _log(LogLevel.Warn, $"DNS 刷新失败: {ex.Message}"); }
    }

    private void OnProgress(string domain, string stage, string? ip, long? latency, int completed, int total) =>
        ProgressChanged?.Invoke(this, new UpdateProgress
        {
            CurrentDomain = domain,
            Stage = stage,
            CurrentIp = ip,
            LatencyMs = latency,
            Completed = completed,
            Total = total
        });
}
