using System.Windows.Input;

namespace FastGithub.ViewModels;

public class MainWindowViewModel : ViewModelBase
{
    public DashboardViewModel Dashboard { get; }
    public ConfigViewModel Config { get; }
    public LogViewModel Log { get; }

    private int _selectedIndex;
    public int SelectedIndex { get => _selectedIndex; set => SetProperty(ref _selectedIndex, value); }

    public ICommand SelectDashboardCommand { get; }
    public ICommand SelectConfigCommand { get; }
    public ICommand SelectLogCommand { get; }

    public MainWindowViewModel(DashboardViewModel dashboard, ConfigViewModel config, LogViewModel log)
    {
        Dashboard = dashboard;
        Config = config;
        Log = log;
        SelectDashboardCommand = new RelayCommand(_ => SelectedIndex = 0);
        SelectConfigCommand = new RelayCommand(_ => SelectedIndex = 1);
        SelectLogCommand = new RelayCommand(_ => SelectedIndex = 2);
    }
}
