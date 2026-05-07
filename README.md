# PixelOS amd64 Remix 

![Syntax Check](https://github.com/LukeLeFox/pixelos-amd64-remix/actions/workflows/syntax-check.yml/badge.svg)
![Status](https://img.shields.io/badge/status-experimental-orange)
![Target](https://img.shields.io/badge/target-Debian%2013%20amd64-blue)
![License](https://img.shields.io/badge/license-MIT-green)

<h3 align="center"><strong><em>Vibecoded with ❤️ by Luke and ChatGPT</em></strong></h3>

Unofficial post-install tooling to build a Raspberry Pi Desktop / PIXEL-like environment on a clean Debian 13 Trixie amd64 installation.

The repository name is **PixelOS amd64 Remix**; internally, some scripts and reports still use the `rpd-amd64` prefix because the technical base is Raspberry Pi Desktop / RPD.

This project does **not** produce an official Raspberry Pi OS image. It keeps Debian as the base operating system and adds selected Raspberry Pi Desktop packages with conservative APT pinning and documented workarounds.

## Project status

Experimental but usable.

Tested by installing a clean Debian 13 Trixie amd64 base system with SSH server, then running the post-install script. The stable target session is currently:

```text
DESKTOP_SESSION=rpd-x
XDG_SESSION_TYPE=x11
```

Wayland/Labwc packages can be installed, but the default login session is intentionally kept on X11 because it has proven more stable on generic amd64/VM environments.

## What the script does

- Adds the Raspberry Pi Debian archive with a dedicated keyring.
- Applies conservative APT pinning so Debian remains the base system.
- Installs Raspberry Pi Desktop / RPD packages.
- Handles the APT/Sequoia SHA1 verification issue seen with the Raspberry Pi archive key.
- Creates local dummy packages for missing `lpplug-netman` / `wfplug-netman` dependencies when they are unavailable on amd64.
- Forces LightDM to use a stable X11 session by default: `rpd-x`.
- Optionally migrates the primary network interface to NetworkManager so the LXDE/RPD network applet can see it.
- Hides or safely removes Raspberry Pi-specific tools that are not useful on generic PCs.
- Writes an installation report under `/var/log/rpd-amd64-report`.

## Quick start

Run this on a fresh Debian 13 Trixie amd64 installation:

```bash
sudo apt update
sudo apt install -y git ca-certificates

git clone https://github.com/LukeLeFox/pixelos-amd64-remix.git
cd pixelos-amd64-remix

chmod +x scripts/rpd-amd64-postinstall.sh
sudo ./scripts/rpd-amd64-postinstall.sh --mode both --profile standard --cleanup safe --default-session rpd-x
```

For the safest first test:

```bash
sudo ./scripts/rpd-amd64-postinstall.sh --mode x11 --profile standard --cleanup safe --default-session rpd-x
```

When running from a local console or VM console, and you want the LXDE network applet to manage the primary interface:

```bash
sudo ./scripts/rpd-amd64-postinstall.sh \
  --mode both \
  --profile standard \
  --cleanup safe \
  --default-session rpd-x \
  --network-manager-takeover yes
```

The default `--network-manager-takeover auto` mode skips the migration when it detects an SSH session, to avoid dropping remote access.

## Verification after reboot

```bash
echo "$DESKTOP_SESSION"
echo "$XDG_SESSION_TYPE"
systemctl status lightdm --no-pager
nmcli device status
cat /var/log/rpd-amd64-report/summary.txt
```

Expected stable values:

```text
rpd-x
x11
```

## Recommended test environment

- Debian 13 Trixie amd64.
- Base system + SSH server only.
- VM snapshot before running the script.
- Local console access for the first test.

## Main options

```text
--mode x11|wayland|both
--profile minimal|standard|full
--cleanup safe|none
--default-session SESSION
--network-manager-takeover auto|yes|no
--dummy-netman auto|yes|no
--legacy-sha1-until YYYY-MM-DD
--no-sha1-workaround
--no-lightdm-config
--dry-run
```

Show full help:

```bash
sudo ./scripts/rpd-amd64-postinstall.sh --help
```

## NetworkManager note

On Debian minimal/server installations, the primary interface is often configured through `ifupdown`. In that case the graphical network applet may show only loopback, even though the system has a valid IP and internet access.

The script can migrate the primary interface to NetworkManager:

```bash
sudo ./scripts/rpd-amd64-postinstall.sh --mode both --profile standard --network-manager-takeover yes
```

Do this from a local console, not over SSH, unless you are prepared for a temporary network interruption.

## Wallpaper locations

Useful commands:

```bash
find /usr/share -type d | grep -Ei 'wallpaper|background|rpd|pix'

find /usr/share \
  -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) \
  | grep -Ei 'rpd|wallpaper|background|pix|raspberry'

grep -R "wallpaper=" ~/.config/pcmanfm /etc/xdg/pcmanfm 2>/dev/null
```

Open the LXDE desktop preference dialog:

```bash
pcmanfm --desktop-pref
```

## Diagnostics

```bash
sudo ./scripts/rpd-amd64-diagnose.sh
```

The diagnostic script creates a tarball under `/tmp` with LightDM logs, session files, network state, APT policy and installed package information.

## Known limitations

See [docs/KNOWN_LIMITATIONS.md](docs/KNOWN_LIMITATIONS.md).

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Security considerations

See [SECURITY.md](SECURITY.md).

## Disclaimer

This is an unofficial community experiment. It is not affiliated with, endorsed by, or supported by Raspberry Pi Ltd., Debian, or any related project.

Raspberry Pi, Raspberry Pi OS and related names are trademarks of their respective owners.
