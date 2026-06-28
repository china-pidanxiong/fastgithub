using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Net;
using System.Threading;

namespace FastGithub.Launcher;

/// <summary>
/// 下载并静默安装 .NET 9 Desktop Runtime。
/// </summary>
public sealed class RuntimeInstaller : IDisposable
{
    /// <summary>
    /// .NET 9.0.17 Desktop Runtime win-x64 installer 直链。
    /// 实测可用：builds.dotnet.microsoft.com 是 .NET 8+ 引入的稳定 URL 模式（旧 download.visualstudio.microsoft.com 的 hash 路径会失效）。
    /// 9.0.17 是 2026-06-09 发布的 .NET 9 最新累积更新版本。
    /// </summary>
    public const string DownloadUrl =
        "https://builds.dotnet.microsoft.com/dotnet/WindowsDesktop/9.0.17/windowsdesktop-runtime-9.0.17-win-x64.exe";

    /// <summary>
    /// 安装包文件名。
    /// </summary>
    public const string InstallerFileName = "windowsdesktop-runtime-9.0.17-win-x64.exe";

    private readonly WebClient _client = new WebClient();

    /// <summary>
    /// 下载进度变化事件，参数为 0-100 的百分比。
    /// </summary>
    public event Action<int> DownloadProgressChanged;

    /// <summary>
    /// 安装阶段开始事件。
    /// </summary>
    public event Action InstallStarted;

    /// <summary>
    /// 计算临时安装包路径（%TEMP%\InstallerFileName）。
    /// </summary>
    /// <returns>临时安装包完整路径。</returns>
    public static string GetTempInstallerPath() =>
        Path.Combine(Path.GetTempPath(), InstallerFileName);

    /// <summary>
    /// 执行下载 + 静默安装。
    /// </summary>
    /// <returns>安装成功返回 true，否则返回 false。</returns>
    public bool Install()
    {
        var tempPath = GetTempInstallerPath();
        CleanStaleTempFile(tempPath);

        var done = new ManualResetEventSlim(false);
        Exception downloadError = null;

        _client.DownloadProgressChanged += (s, e) =>
            DownloadProgressChanged?.Invoke(e.ProgressPercentage);
        _client.DownloadFileCompleted += (s, e) =>
        {
            downloadError = e.Error;
            done.Set();
        };

        try
        {
            _client.DownloadFileAsync(new Uri(DownloadUrl), tempPath);
            done.Wait();
        }
        catch (Exception)
        {
            return false;
        }

        if (downloadError != null) return false;

        InstallStarted?.Invoke();

        var psi = new ProcessStartInfo
        {
            FileName = tempPath,
            Arguments = "/quiet /norestart",
            UseShellExecute = false,
            CreateNoWindow = true
        };

        try
        {
            var p = Process.Start(psi);
            p.WaitForExit();
            return p.ExitCode == 0;
        }
        catch (Win32Exception)
        {
            return false;
        }
    }

    private static void CleanStaleTempFile(string path)
    {
        if (File.Exists(path))
        {
            try { File.Delete(path); }
            catch (IOException) { /* 占用中，忽略 */ }
        }
    }

    public void Dispose() => _client.Dispose();
}
