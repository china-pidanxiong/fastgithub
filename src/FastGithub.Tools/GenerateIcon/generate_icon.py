from PIL import Image, ImageDraw, ImageFont
import struct
import sys
import os
import io

def create_icon(size):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    bg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)
    bg_draw.ellipse([0, 0, size - 1, size - 1], fill=(0x24, 0x29, 0x2f, 255))

    overlay = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    overlay_draw = ImageDraw.Draw(overlay)
    for y in range(size):
        t = y / size
        rc = int(0x24 * (1 - t) + 0x2d * t)
        gc = int(0x29 * (1 - t) + 0xa4 * t)
        bc = int(0x2f * (1 - t) + 0x4e * t)
        overlay_draw.line([(0, y), (size, y)], fill=(rc, gc, bc, 255))

    img = Image.alpha_composite(img, Image.composite(overlay, bg, bg))
    draw = ImageDraw.Draw(img)

    try:
        font_size = int(size * 0.55)
        for f in ["seguihis.ttf", "segoeui.ttf", "arialbd.ttf", "arial.ttf"]:
            try:
                font = ImageFont.truetype(f, font_size)
                break
            except:
                continue
        else:
            font = ImageFont.load_default()
    except:
        font = ImageFont.load_default()

    text = "G"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    tx = (size - tw) / 2 - bbox[0]
    ty = (size - th) / 2 - bbox[1] - size * 0.06
    draw.text((tx, ty), text, fill=(255, 255, 255, 255), font=font)

    badge_size = int(size * 0.38)
    badge_x = size - badge_size + int(size * 0.04)
    badge_y = -int(size * 0.04)
    draw.ellipse([badge_x, badge_y, badge_x + badge_size, badge_y + badge_size],
                 fill=(0x2d, 0xa4, 0x4e, 255))

    line_w = max(2, int(size * 0.055))
    cx_b = badge_x + badge_size / 2
    cy_b = badge_y + badge_size / 2
    p1 = (cx_b - badge_size * 0.28, cy_b + badge_size * 0.05)
    p2 = (cx_b - badge_size * 0.08, cy_b + badge_size * 0.28)
    p3 = (cx_b + badge_size * 0.32, cy_b - badge_size * 0.22)
    draw.line([p1, p2], fill=(255, 255, 255, 255), width=line_w)
    draw.line([p2, p3], fill=(255, 255, 255, 255), width=line_w)

    return img

def save_ico(images, output_path):
    png_datas = []
    for img in images:
        buf = io.BytesIO()
        img.save(buf, format='PNG')
        png_datas.append(buf.getvalue())

    with open(output_path, 'wb') as f:
        f.write(struct.pack('<HHH', 0, 1, len(images)))
        header_size = 6 + 16 * len(images)
        offset = header_size
        for i, img in enumerate(images):
            w = 0 if img.width >= 256 else img.width
            h = 0 if img.height >= 256 else img.height
            f.write(struct.pack('<BBBBHHII',
                w, h, 0, 0, 1, 32,
                len(png_datas[i]), offset))
            offset += len(png_datas[i])
        for data in png_datas:
            f.write(data)

def main():
    output_path = sys.argv[1] if len(sys.argv) > 1 else "AppIcon.ico"
    sizes = [16, 32, 48, 64, 128, 256]

    print("Generating 256x256 base icon...")
    base = create_icon(256)

    images = []
    for s in sizes:
        if s == 256:
            images.append(base)
        else:
            resized = base.resize((s, s), Image.LANCZOS)
            images.append(resized)
        print(f"  {s}x{s} done")

    save_ico(images, output_path)
    print(f"\nIcon saved to: {output_path}")
    print(f"File size: {os.path.getsize(output_path)} bytes")

if __name__ == "__main__":
    main()
