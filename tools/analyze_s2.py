import glob
import os
import sys

from PIL import Image, ImageChops, ImageStat

root = sys.argv[1] if len(sys.argv) > 1 else r"build\s2frames"
files = sorted(glob.glob(os.path.join(root, "f*.png")))
if not files:
    print("no frames")
    sys.exit(1)

rows = []
prev = None
for f in files:
    im = Image.open(f).convert("RGB")
    gray = im.convert("L")
    mean = ImageStat.Stat(gray).mean[0]
    diff = 0.0
    if prev is not None:
        diff = ImageStat.Stat(ImageChops.difference(prev, im)).mean[0]
    rows.append((os.path.basename(f), mean, diff, im.size))
    prev = im

means = [r[1] for r in rows]
diffs = [r[2] for r in rows]
black = [r for r in rows if r[1] < 12]
print(f"frames={len(rows)} size={rows[0][3]}")
print(f"brightness min={min(means):.1f} max={max(means):.1f} avg={sum(means)/len(means):.1f}")
print(f"black_frames(mean<12)={len(black)}")
print(f"frame_diff avg={sum(diffs)/len(diffs):.2f} max={max(diffs):.2f}")
dup = [rows[i][0] for i in range(1, len(rows)) if rows[i][2] < 0.05]
print(f"identical_to_prev={len(dup)}")
print("first10:")
for r in rows[:10]:
    print(f"  {r[0]} mean={r[1]:.1f} diff={r[2]:.2f}")
print("largest diffs:")
for r in sorted(rows[1:], key=lambda x: x[2], reverse=True)[:5]:
    print(f"  {r[0]} mean={r[1]:.1f} diff={r[2]:.2f}")

# contact sheet: every 8th frame
thumb_w = 320
picks = files[::8][:16]
thumbs = []
for f in picks:
    im = Image.open(f).convert("RGB")
    h = int(im.height * thumb_w / im.width)
    thumbs.append((os.path.basename(f), im.resize((thumb_w, h))))
if thumbs:
    cols = 4
    rows_n = (len(thumbs) + cols - 1) // cols
    th = max(t.height for _, t in thumbs)
    sheet = Image.new("RGB", (cols * thumb_w, rows_n * th), (0, 0, 0))
    for i, (name, t) in enumerate(thumbs):
        sheet.paste(t, ((i % cols) * thumb_w, (i // cols) * th))
    out = os.path.join(root, "contact-sheet.png")
    sheet.save(out)
    print("contact_sheet=" + out)
