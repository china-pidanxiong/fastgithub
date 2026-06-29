using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;

int[] sizes = { 16, 32, 48, 64, 128, 256 };
string outputPath = args.Length > 0 ? args[0] : "AppIcon.ico";

using var iconStream = new FileStream(outputPath, FileMode.Create);
using var writer = new BinaryWriter(iconStream);

writer.Write((short)0);
writer.Write((short)1);
writer.Write((short)sizes.Length);

List<byte[]> imageDataList = new();
List<int> imageSizes = new();

int dataOffset = 6 + 16 * sizes.Length;

foreach (var size in sizes)
{
    using var bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb);
    using var g = Graphics.FromImage(bmp);
    g.SmoothingMode = SmoothingMode.AntiAlias;
    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
    g.PixelOffsetMode = PixelOffsetMode.HighQuality;

    using var bgBrush = new LinearGradientBrush(
        new Rectangle(0, 0, size, size),
        Color.FromArgb(0x24, 0x29, 0x2f),
        Color.FromArgb(0x2d, 0xa4, 0x4e),
        LinearGradientMode.ForwardDiagonal);
    g.FillEllipse(bgBrush, 0, 0, size - 1, size - 1);

    using var font = new Font("Segoe UI", size * 0.55f, FontStyle.Bold);
    var textSize = g.MeasureString("G", font);
    g.DrawString("G", font, Brushes.White,
        (size - textSize.Width) / 2,
        (size - textSize.Height) / 2 - size * 0.06f);

    float badgeSize = size * 0.38f;
    float badgeX = size - badgeSize + size * 0.04f;
    float badgeY = -size * 0.04f;
    using var badgeBrush = new SolidBrush(Color.FromArgb(0x2d, 0xa4, 0x4e));
    g.FillEllipse(badgeBrush, badgeX, badgeY, badgeSize, badgeSize);
    using var whitePen = new Pen(Color.White, Math.Max(1.5f, size * 0.055f));
    whitePen.StartCap = LineCap.Round;
    whitePen.EndCap = LineCap.Round;
    float cx = badgeX + badgeSize / 2;
    float cy = badgeY + badgeSize / 2;
    g.DrawLine(whitePen, cx - badgeSize * 0.28f, cy + badgeSize * 0.05f,
        cx - badgeSize * 0.08f, cy + badgeSize * 0.28f);
    g.DrawLine(whitePen, cx - badgeSize * 0.08f, cy + badgeSize * 0.28f,
        cx + badgeSize * 0.32f, cy - badgeSize * 0.22f);

    using var ms = new MemoryStream();
    bmp.Save(ms, ImageFormat.Png);
    var bytes = ms.ToArray();
    imageDataList.Add(bytes);
    imageSizes.Add(bytes.Length);
}

for (int i = 0; i < sizes.Length; i++)
{
    byte w = (byte)(sizes[i] >= 256 ? 0 : sizes[i]);
    byte h = (byte)(sizes[i] >= 256 ? 0 : sizes[i]);
    writer.Write(w);
    writer.Write(h);
    writer.Write((byte)0);
    writer.Write((byte)0);
    writer.Write((short)1);
    writer.Write((short)32);
    writer.Write(imageSizes[i]);
    writer.Write(dataOffset);
    dataOffset += imageSizes[i];
}

for (int i = 0; i < sizes.Length; i++)
{
    writer.Write(imageDataList[i]);
}

Console.WriteLine($"Icon saved to: {outputPath}");
