namespace FastGithub.Models;

public class UpdateProgress
{
    public string CurrentDomain { get; init; } = string.Empty;
    public string Stage { get; init; } = string.Empty;
    public string? CurrentIp { get; init; }
    public long? LatencyMs { get; init; }
    public int Completed { get; init; }
    public int Total { get; init; }
    public double Percent => Total == 0 ? 0 : (double)Completed / Total * 100;
}
