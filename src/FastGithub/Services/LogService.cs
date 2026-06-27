using System.IO;
using System.Text;
using FastGithub.Models;

namespace FastGithub.Services;

public record LogEntry(DateTime Timestamp, LogLevel Level, string Message);

/// <summary>
/// 写文件 + 事件推送 UI。文件句柄在构造时打开，写入加锁保证线程安全。
/// </summary>
public class LogService
{
    private readonly string _logFile;
    private readonly object _lock = new();
    private readonly StreamWriter? _writer;

    public event Action<LogEntry>? OnLog;

    public LogService(string logFile)
    {
        _logFile = logFile;
        try
        {
            _writer = new StreamWriter(logFile, append: true, Encoding.UTF8) { AutoFlush = true };
        }
        catch { _writer = null; }
    }

    public void Log(LogLevel level, string message)
    {
        var entry = new LogEntry(DateTime.Now, level, message);
        lock (_lock)
        {
            try { _writer?.WriteLine($"[{entry.Timestamp:yyyy-MM-dd HH:mm:ss}] [{level}] {message}"); }
            catch { }
        }
        OnLog?.Invoke(entry);
    }

    public void Info(string msg) => Log(LogLevel.Info, msg);
    public void Warn(string msg) => Log(LogLevel.Warn, msg);
    public void Error(string msg) => Log(LogLevel.Error, msg);
    public void Success(string msg) => Log(LogLevel.Success, msg);

    public void OpenLogFile()
    {
        try { System.Diagnostics.Process.Start("notepad.exe", _logFile); }
        catch { }
    }

    public void Dispose() => _writer?.Dispose();
}
