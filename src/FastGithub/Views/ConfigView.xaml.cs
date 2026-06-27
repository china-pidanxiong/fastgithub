using System.Windows;
using FastGithub.ViewModels;
using MessageBox = System.Windows.MessageBox;

namespace FastGithub.Views;

public partial class ConfigView : System.Windows.Controls.UserControl
{
    public ConfigView() => InitializeComponent();

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        if (DataContext is ConfigViewModel vm)
        {
            vm.Save();
            MessageBox.Show("配置已保存，下次刷新生效。", "提示", MessageBoxButton.OK, MessageBoxImage.Information);
        }
    }

    private void Reset_Click(object sender, RoutedEventArgs e)
    {
        if (DataContext is ConfigViewModel vm)
        {
            vm.Reset();
            MessageBox.Show("已重置为默认配置（需点击保存才会生效）。", "提示", MessageBoxButton.OK, MessageBoxImage.Information);
        }
    }
}
