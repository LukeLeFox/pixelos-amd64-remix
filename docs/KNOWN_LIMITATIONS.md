# Known limitations

## Unofficial remix

This project does not create an official Raspberry Pi OS image for amd64. It keeps Debian as the base system and installs selected Raspberry Pi Desktop / RPD packages from the Raspberry Pi archive.

## Wayland/Labwc is experimental on this target

The RPD Wayland session can be installed, but it may fail on generic amd64 systems or virtual machines. The tested stable default is currently:

```text
rpd-x on X11
```

Recommended default LightDM session:

```text
user-session=rpd-x
```

## Raspberry Pi-specific tools

Some packages are designed for Raspberry Pi hardware and are not useful on a generic PC or VM. The script hides or safely removes several of these when `--cleanup safe` is used.

Examples:

- GPIO-related Python packages.
- Raspberry Pi firmware utilities.
- Raspberry Pi imaging or first-boot tools.
- Raspberry Pi configuration menu entries.

## Dummy netman packages

On amd64, the RPD `lpplug-netman` and/or `wfplug-netman` packages may be missing or not installable. The script can create local dummy packages to satisfy the desktop meta-package dependencies and use Debian NetworkManager tools instead.

These dummy packages are named:

```text
lpplug-netman
wfplug-netman
```

with local version:

```text
99.0-rpd-amd64dummy1
```

## APT/Sequoia SHA1 compatibility override

APT on Debian Trixie may reject legacy repository key signatures involving SHA1. The script can create a temporary Sequoia policy override for APT.

This is intentionally documented and reversible. Remove it later with:

```bash
sudo rm -f /etc/crypto-policies/back-ends/apt-sequoia.config
sudo apt update
```

## NetworkManager takeover

On Debian minimal/server installations, networking may be managed by `ifupdown`. In that case, the graphical network applet may show only loopback.

The script can migrate the primary interface to NetworkManager with:

```bash
--network-manager-takeover yes
```

This should be done from a local console when possible.
