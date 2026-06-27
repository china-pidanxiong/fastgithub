namespace FastGithub.ViewModels;

public class MainWindowViewModel
{
    public DashboardViewModel Dashboard { get; }
    public ConfigViewModel Config { get; }
    public LogViewModel Log { get; }

    public MainWindowViewModel(DashboardViewModel dashboard, ConfigViewModel config, LogViewModel log)
    {
        Dashboard = dashboard;
        Config = config;
        Log = log;
    }
}
