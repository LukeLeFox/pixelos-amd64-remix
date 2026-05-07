# Changelog

## 1.1.2

- Updated repository branding to PixelOS amd64 Remix.
- Replaced placeholder GitHub username with LukeLeFox.
- Removed the external shell-analysis GitHub Action dependency.
- Added a lightweight Bash syntax-only GitHub Action.
- Updated packaging target to use pixelos-amd64-remix.

## 1.1.1

- Added final repository layout.
- Added diagnostic helper script.
- Added documentation for troubleshooting, known limitations, wallpaper discovery and rollback.
- Added NetworkManager takeover handling for Debian minimal/server installs.
- Kept X11 `rpd-x` as the recommended stable default.

## 1.1.0

- Added NetworkManager takeover logic.
- Added support for fixing LXDE/RPD network applet showing only loopback.

## 1.0.0

- Integrated APT/Sequoia SHA1 compatibility workaround.
- Added Raspberry Pi archive pinning.
- Added dummy `lpplug-netman` and `wfplug-netman` package generation.
- Added LightDM X11 recovery/default configuration.
- Added installation report generation.
