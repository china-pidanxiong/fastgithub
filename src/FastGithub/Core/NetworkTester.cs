using System.Net.NetworkInformation;
using System.Net.Sockets;

namespace FastGithub.Core;

public class NetworkTester : INetworkTester
{
    private readonly int _timeoutMs;

    public NetworkTester(int timeoutMs) => _timeoutMs = timeoutMs;

    public bool IsValidIp(string ip) =>
        System.Net.IPAddress.TryParse(ip, out var addr) && addr.AddressFamily == AddressFamily.InterNetwork;

    public async Task<bool> TestPort443Async(string ip)
    {
        try
        {
            using var client = new TcpClient();
            using var cts = new CancellationTokenSource(_timeoutMs);
            await client.ConnectAsync(ip, 443, cts.Token);
            return true;
        }
        catch { return false; }
    }

    public async Task<long?> TestPingLatencyAsync(string ip)
    {
        try
        {
            using var ping = new Ping();
            var reply = await ping.SendPingAsync(ip, _timeoutMs);
            return reply.Status == IPStatus.Success ? reply.RoundtripTime : null;
        }
        catch { return null; }
    }
}
