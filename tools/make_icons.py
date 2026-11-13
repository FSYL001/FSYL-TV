"""Generate FSYL TV's original icon set.

The mark is a rounded gradient screen with a play glyph; it deliberately does not
reuse Kazumi's logo or MoonTV artwork. Run with Pillow installed:
    python tools/make_icons.py
"""

import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

TEAL = (53, 199, 178)
INDIGO = (122, 140, 255)
DARK = (16, 16, 20)


def gradient(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            r = int(TEAL[0] + (INDIGO[0] - TEAL[0]) * t)
            g = int(TEAL[1] + (INDIGO[1] - TEAL[1]) * t)
            b = int(TEAL[2] + (INDIGO[2] - TEAL[2]) * t)
            px[x, y] = (r, g, b, 255)
    return img


def rounded_mask(size, radius_ratio=0.23):
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    r = int(size * radius_ratio)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=255)
    return mask


def make_icon(size):
    base = gradient(size)
    base.putalpha(rounded_mask(size))

    # Subtle inner highlight line.
    d = ImageDraw.Draw(base)
    inset = int(size * 0.085)
    d.rounded_rectangle(
        [inset, inset, size - inset, size - inset],
        radius=int(size * 0.16),
        outline=(255, 255, 255, 60),
        width=max(1, size // 128),
    )

    # Play triangle.
    cx, cy = size * 0.52, size * 0.5
    s = size * 0.235
    pts = [
        (cx - s * 0.72, cy - s),
        (cx - s * 0.72, cy + s),
        (cx + s * 0.95, cy),
    ]
    d.polygon(pts, fill=DARK + (255,))

    return base


def save_png(path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    make_icon(size).save(path, "PNG")
    print("png", path)


def save_ico(path, size=256):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    icon = make_icon(size)
    icon.save(
        path,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    print("ico", path)


def main():
    asset_dir = os.path.join(ROOT, "app", "assets", "images", "logo")
    save_png(os.path.join(asset_dir, "logo_rounded.png"), 512)
    save_png(os.path.join(asset_dir, "logo_android.png"), 512)
    save_png(os.path.join(asset_dir, "logo_ios.png"), 512)
    save_png(os.path.join(asset_dir, "logo_linux.png"), 512)
    save_ico(os.path.join(asset_dir, "logo_windows.ico"))
    save_ico(os.path.join(asset_dir, "logo_lanczos.ico"), 64)

    runner_res = os.path.join(ROOT, "app", "windows", "runner", "resources")
    save_ico(os.path.join(runner_res, "app_icon.ico"))

    public = os.path.join(ROOT, "moonserver", "public")
    save_png(os.path.join(public, "logo.png"), 512)
    save_ico(os.path.join(public, "favicon.ico"))
    for s in (192, 256, 384, 512):
        save_png(os.path.join(public, "icons", f"icon-{s}x{s}.png"), s)


if __name__ == "__main__":
    main()
