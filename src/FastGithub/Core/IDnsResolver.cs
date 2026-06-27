namespace FastGithub.Core;

public interface IDnsResolver
{
    Task<List<string>> ResolveAsync(string domain, IReadOnlyList<string> dnsServers, int timeoutMs);
}
