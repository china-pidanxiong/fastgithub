namespace FastGithub.Models;

/// <summary>
/// 刷新结果：UpdateAsync 通过此类型向调用方传递成功计数与各域名延迟。
/// </summary>
public record UpdateResult(
    int Success,
    int Total,
    Dictionary<string, long> Latencies);
