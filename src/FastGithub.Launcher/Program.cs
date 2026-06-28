using System;
using System.Diagnostics;
using System.IO;
using System.Threading;
using System.Windows.Forms;

namespace FastGithub.Launcher;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);

        try
        {
            if (RuntimeDetector.IsDesktopRuntime9Installed())
            {
                StartMainApp();
                return;
            }

            var result = MessageBox.Show(
                "未检测到 .NET 9 Desktop Runtime，是否自动下载并安装？",
                "运行环境缺失",
                MessageBoxButtons.YesNo,
                MessageBoxIcon.Question);

            if (result != DialogResult.Yes) return;

            if (!RunInstallWithProgress())
            {
                MessageBox.Show(
                    $".NET 9 Runtime 安装失败。请手动下载安装：{Environment.NewLine}{RuntimeInstaller.DownloadUrl}",
                    "安装失败",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return;
            }

            StartMainApp();
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                $"发生错误：{ex.Message}",
                "错误",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
        }
    }

    private static bool RunInstallWithProgress()
    {
        using var form = new ProgressForm();
        using var installer = new RuntimeInstaller();

        installer.DownloadProgressChanged += form.UpdateDownloadProgress;
        installer.InstallStarted += form.ShowInstallProgress;

        bool success = false;
        Exception error = null;

        var worker = new Thread(() =>
        {
            try { success = installer.Install(); }
            catch (Exception ex) { error = ex; }
            form.CloseGracefully();
        })
        {
            IsBackground = true
        };
        worker.Start();

        Application.Run(form);
        worker.Join();

        if (error != null)
            throw error;

        return success;
    }

    private static void StartMainApp()
    {
        var baseDir = AppDomain.CurrentDomain.BaseDirectory;
        var appPath = Path.Combine(baseDir, "FastGithub.App.exe");

        if (!File.Exists(appPath))
        {
            MessageBox.Show(
                $"未找到主程序：{appPath}",
                "启动失败",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return;
        }

        Process.Start(appPath);
    }
}
