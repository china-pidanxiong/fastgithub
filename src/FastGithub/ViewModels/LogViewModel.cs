using System.Collections.ObjectModel;
using FastGithub.Services;

namespace FastGithub.ViewModels;

public class LogViewModel : ViewModelBase
{
    public ObservableCollection<LogEntry> Logs { get; } = new();

    private string _levelFilter = "全部";
    public string LevelFilter { get => _levelFilter; set => SetProperty(ref _levelFilter, value); }

    // 由后台线程调用，需切回 UI 线程才能更新 ObservableCollection
    public void AddLog(LogEntry entry)
    {
        System.Windows.Application.Current?.Dispatcher.Invoke(() => Logs.Add(entry));
    }

    public void Clear() => Logs.Clear();
}
