using System.IO;
using System.Text;

namespace FastGithub.Core;

/// <summary>
/// hosts 文件读写 + 标记块管理（# === GitHub Hosts Start/End ===）+ 备份。
/// </summary>
public class HostsFileManager
{
    private readonly string _hostsPath;
    private readonly string _startMarker;
    private readonly string _endMarker;
    private const int MaxRetry = 5;
    private const int RetryDelayMs = 500;

    public HostsFileManager(string hostsPath, string startMarker, string endMarker)
    {
        _hostsPath = hostsPath;
        _startMarker = startMarker;
        _endMarker = endMarker;
    }

    public string Read()
    {
        Exception? last = null;
        for (int i = 0; i < MaxRetry; i++)
        {
            try { return File.ReadAllText(_hostsPath, Encoding.UTF8); }
            catch (Exception ex) { last = ex; Thread.Sleep(RetryDelayMs); }
        }
        throw new IOException($"读取 hosts 文件失败（重试 {MaxRetry} 次）：{_hostsPath}", last);
    }

    public void Write(string content)
    {
        Exception? last = null;
        for (int i = 0; i < MaxRetry; i++)
        {
            try { File.WriteAllText(_hostsPath, content, Encoding.UTF8); return; }
            catch (Exception ex) { last = ex; Thread.Sleep(RetryDelayMs); }
        }
        throw new IOException($"写入 hosts 文件失败（重试 {MaxRetry} 次）：{_hostsPath}", last);
    }

    public void UpdateManagedEntries(IReadOnlyDictionary<string, string> entries)
    {
        var content = Read();
        var lines = entries.Where(e => !string.IsNullOrEmpty(e.Value))
                           .Select(e => $"{e.Value} {e.Key}");
        var block = $"{_startMarker}\n{string.Join("\n", lines)}\n{_endMarker}";

        var startIndex = content.IndexOf(_startMarker);
        string newContent;
        if (startIndex >= 0)
        {
            var endIndex = content.IndexOf(_endMarker, startIndex);
            if (endIndex >= 0)
            {
                endIndex += _endMarker.Length;
                newContent = content.Substring(0, startIndex) + block + content.Substring(endIndex);
            }
            else
            {
                newContent = content.Substring(0, startIndex) + block + "\n";
            }
        }
        else
        {
            if (!content.EndsWith("\n")) content += "\n";
            newContent = content + "\n" + block + "\n";
        }
        Write(newContent);
    }

    public bool ClearManagedEntries()
    {
        var content = Read();
        var startIndex = content.IndexOf(_startMarker);
        if (startIndex < 0) return true;

        var endIndex = content.IndexOf(_endMarker, startIndex);
        if (endIndex < 0)
        {
            Write(content.Substring(0, startIndex).TrimEnd() + "\n");
            return true;
        }
        endIndex += _endMarker.Length;

        var removeStart = startIndex;
        if (removeStart > 0 && content[removeStart - 1] == '\n') removeStart--;
        var removeEnd = endIndex;
        if (removeEnd < content.Length && content[removeEnd] == '\n') removeEnd++;

        var newContent = content.Substring(0, removeStart) + content.Substring(removeEnd);
        Write(newContent.TrimEnd() + "\n");
        return true;
    }

    public bool Backup(string backupDir)
    {
        try
        {
            var ts = DateTime.Now.ToString("yyyyMMddHHmmss");
            var backupPath = Path.Combine(backupDir, $"hosts.githubbak.{ts}");
            File.Copy(_hostsPath, backupPath, overwrite: true);
            return true;
        }
        catch { return false; }
    }

    public void RemoveOldBackups(string backupDir, int maxCount)
    {
        if (maxCount <= 0) return;
        try
        {
            var backups = Directory.GetFiles(backupDir, "hosts.githubbak.*")
                .Select(f => new FileInfo(f))
                .OrderByDescending(f => f.CreationTime)
                .Skip(maxCount);
            foreach (var b in backups)
                try { b.Delete(); } catch { }
        }
        catch { }
    }
}
