# FSYL TV brand artwork

`fsyl_logo_source.png` is the brand artwork supplied by the project owner
(1600x1600, white background). It replaces the temporary gradient mark and is
**not** derived from Kazumi's or MoonTV's logos.

`tools/make_icons.py` center-crops it, applies a rounded mask and regenerates:

- `app/assets/images/logo/logo_{rounded,android,ios,linux}.png`
- `app/assets/images/logo/logo_{windows,lanczos}.ico`
- `app/windows/runner/resources/app_icon.ico`
- `moonserver/public/logo.png`, `favicon.ico`, `icons/icon-*.png`

Run:

```powershell
python tools/make_icons.py
```

Upstream Kazumi/MoonTV artwork is still present in their original asset
directories for license/attribution purposes, but is no longer used as the
FSYL TV application icon.
