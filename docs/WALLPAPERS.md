# Wallpapers

To find wallpapers installed by the desktop environment:

```bash
find /usr/share -type d | grep -Ei 'wallpaper|background|rpd|pix'
```

Search image files:

```bash
find /usr/share \
  -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) \
  | grep -Ei 'rpd|wallpaper|background|pix|raspberry'
```

Check the current LXDE/PCManFM desktop wallpaper setting:

```bash
grep -R "wallpaper=" ~/.config/pcmanfm /etc/xdg/pcmanfm 2>/dev/null
```

Open the graphical wallpaper preference window:

```bash
pcmanfm --desktop-pref
```
