namespace FastGithub.Models;

public class HostsEntry
{
    public string Domain { get; set; } = string.Empty;
    public string? Ip { get; set; }
    public string Status { get; set; } = "待刷新";
    public long? LatencyMs { get; set; }
    public DateTime? LastUpdate { get; set; }
}
