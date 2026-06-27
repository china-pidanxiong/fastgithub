using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using FastGithub.Models;

namespace FastGithub.Core;

/// <summary>
/// DNS 解析器：构造 A 记录查询报文，UDP 直连指定 DNS 服务器，绕过本地 hosts。
/// </summary>
public class DnsResolver : IDnsResolver
{
    private static readonly Random Rng = new();

    public byte[] BuildAQuery(string domain)
    {
        using var ms = new MemoryStream();
        using var w = new BinaryWriter(ms);
        var txId = (ushort)Rng.Next(0, 0xFFFF);
        w.Write((ushort)IPAddress.HostToNetworkOrder((short)txId));
        // flags: RD=1（递归）
        w.Write((ushort)IPAddress.HostToNetworkOrder((short)0x0100));
        w.Write((ushort)IPAddress.HostToNetworkOrder((short)1)); // qdcount
        w.Write((ushort)IPAddress.HostToNetworkOrder((short)0)); // ancount
        w.Write((ushort)IPAddress.HostToNetworkOrder((short)0)); // nscount
        w.Write((ushort)IPAddress.HostToNetworkOrder((short)0)); // arcount
        foreach (var label in domain.Split('.'))
        {
            w.Write((byte)label.Length);
            w.Write(Encoding.ASCII.GetBytes(label));
        }
        w.Write((byte)0);
        w.Write((ushort)IPAddress.HostToNetworkOrder((short)1)); // type A
        w.Write((ushort)IPAddress.HostToNetworkOrder((short)1)); // class IN
        return ms.ToArray();
    }

    public List<string> ParseARecords(byte[] response, string domain)
    {
        var ips = new List<string>();
        if (response.Length < 12) return ips;

        int pos = 4;
        var qdcount = ReadU16(response, ref pos);
        var ancount = ReadU16(response, ref pos);
        pos += 4; // nscount + arcount

        for (int i = 0; i < qdcount; i++)
        {
            SkipName(response, ref pos);
            pos += 4; // type + class
        }

        for (int i = 0; i < ancount; i++)
        {
            SkipName(response, ref pos);
            var type = ReadU16(response, ref pos);
            pos += 6; // class + ttl
            var rdlength = ReadU16(response, ref pos);
            if (type == 1 && rdlength == 4) // A record
            {
                ips.Add($"{response[pos]}.{response[pos + 1]}.{response[pos + 2]}.{response[pos + 3]}");
            }
            pos += rdlength;
        }
        return ips;
    }

    public async Task<List<string>> ResolveAsync(string domain, IReadOnlyList<string> dnsServers, int timeoutMs)
    {
        foreach (var dns in dnsServers)
        {
            try
            {
                var query = BuildAQuery(domain);
                using var client = new UdpClient();
                client.Client.ReceiveTimeout = timeoutMs;
                client.Client.SendTimeout = timeoutMs;
                await client.SendAsync(query, query.Length, dns, 53);
                using var cts = new CancellationTokenSource(timeoutMs);
                var result = await client.ReceiveAsync(cts.Token);
                var ips = ParseARecords(result.Buffer, domain);
                if (ips.Count > 0) return ips;
            }
            catch { }
        }
        return new List<string>();
    }

    private static ushort ReadU16(byte[] data, ref int pos)
    {
        var v = (ushort)((data[pos] << 8) | data[pos + 1]);
        pos += 2;
        return v;
    }

    private static void SkipName(byte[] data, ref int pos)
    {
        while (pos < data.Length)
        {
            var len = data[pos];
            if (len == 0) { pos++; return; }
            if ((len & 0xC0) == 0xC0) { pos += 2; return; }
            pos += len + 1;
        }
    }
}
