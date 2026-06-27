using System.IO;

namespace FastGithub.Models;

public class AppConfig
{
    public List<string> Domains { get; set; } = new();
    public List<string> DnsServers { get; set; } = new();
    public string HostsPath { get; set; } = string.Empty;
    public int MaxBackupCount { get; set; } = 10;
    public int TimeoutMs { get; set; } = 3000;

    public static AppConfig CreateDefault() => new()
    {
        Domains = new List<string>
        {
            "github.com", "www.github.com", "api.github.com",
            "raw.githubusercontent.com", "codeload.github.com",
            "objects.githubusercontent.com", "gist.github.com",
            "gist.githubusercontent.com", "cloud.githubusercontent.com",
            "user-images.githubusercontent.com", "avatars.githubusercontent.com",
            "avatars0.githubusercontent.com", "avatars1.githubusercontent.com",
            "avatars2.githubusercontent.com", "avatars3.githubusercontent.com",
            "avatars4.githubusercontent.com", "avatars5.githubusercontent.com",
            "avatars6.githubusercontent.com", "avatars7.githubusercontent.com",
            "github.io", "pkg.github.com", "ghcr.io", "github.community"
        },
        DnsServers = new List<string>
        {
            "114.114.114.114", "119.29.29.29", "223.5.5.5", "8.8.8.8", "1.1.1.1"
        },
        HostsPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.Windows),
            "System32", "drivers", "etc", "hosts"),
        MaxBackupCount = 10,
        TimeoutMs = 3000
    };
}
