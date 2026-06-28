using System.IO;

namespace FastGithub.Launcher;

/// <summary>
/// 检测 .NET 9 Desktop Runtime 是否已安装。
/// </summary>
public static class RuntimeDetector
{
    /// <summary>
    /// 检测本机是否已安装 .NET 9 Desktop Runtime（按默认安装路径判断）。
    /// </summary>
    /// <returns>已安装返回 true，否则返回 false。</returns>
    public static bool IsDesktopRuntime9Installed() =>
        IsDesktopRuntime9Installed(GetDefaultBasePath());

    /// <summary>
    /// 检测指定基目录下是否存在 9.x 版本子目录（可测试重载）。
    /// </summary>
    /// <param name="basePath">Desktop Runtime 共享目录，例如 .../Microsoft.WindowsDesktop.App。</param>
    /// <returns>存在 9.x 子目录返回 true，否则返回 false。</returns>
    internal static bool IsDesktopRuntime9Installed(string basePath)
    {
        if (string.IsNullOrEmpty(basePath) || !Directory.Exists(basePath))
            return false;

        return Directory.GetDirectories(basePath, "9.*").Length > 0;
    }

    private static string GetDefaultBasePath() =>
        Path.Combine(
            System.Environment.GetFolderPath(System.Environment.SpecialFolder.ProgramFiles),
            "dotnet", "shared", "Microsoft.WindowsDesktop.App");
}
