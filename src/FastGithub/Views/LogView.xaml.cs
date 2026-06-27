using System.Windows;

namespace FastGithub.Views;

public partial class LogView : System.Windows.Controls.UserControl
{
    public LogView() => InitializeComponent();

    private void OpenLog_Click(object sender, RoutedEventArgs e)
    {
        var logPath = System.IO.Path.Combine(System.AppContext.BaseDirectory, "github-hosts-update.log");
        try { System.Diagnostics.Process.Start("notepad.exe", logPath); }
        catch { }
    }

    private void Clear_Click(object sender, RoutedEventArgs e)
    {
        if (DataContext is FastGithub.ViewModels.LogViewModel vm)
            vm.Clear();
    }
}
