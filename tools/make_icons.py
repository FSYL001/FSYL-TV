"""Generate FSYL TV's icon set from the user-supplied brand artwork.

Source: app/assets/images/logo/fsyl_logo_source.png (1600x1600, white background).
The artwork is provided by the project owner and is not upstream Kazumi/MoonTV art.
Run with Pillow installed:
    python tools/make_icons.py
"""

import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "app", "assets", "images", "logo", "fsyl_logo_source.png")


def rounded_mask(size, radius_ratio=0.22):
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    r = int(size * radius_ratio)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=r, fill=255)
    return mask


def make_icon(size):
    img = Image.open(SRC).convert("RGBA")
    side = min(img.size)
    left = (img.width - side) // 2
    top = (img.height - side) // 2
    img = img.crop((left, top, left + side, top + side))
    img = img.resize((size, size), Image.LANCZOS)
    mask = rounded_mask(size)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


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
    if not os.path.exists(SRC):
        raise SystemExit(f"missing source artwork: {SRC}")
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
