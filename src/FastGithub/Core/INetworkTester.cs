namespace FastGithub.Core;

public interface INetworkTester
{
    Task<bool> TestPort443Async(string ip);
    Task<long?> TestPingLatencyAsync(string ip);
    bool IsValidIp(string ip);
}
