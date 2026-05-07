# Technical notes

## Design goal

The goal is not to rebuild Raspberry Pi OS for amd64. The goal is to keep Debian amd64 as the base operating system and install enough Raspberry Pi Desktop / RPD packages to provide a similar desktop experience.

## APT pinning model

The Raspberry Pi archive is added with low global priority:

```text
Package: *
Pin: origin "archive.raspberrypi.com"
Pin-Priority: 100
```

Selected RPD-related packages are allowed at a higher priority:

```text
Package: rpd-* pixtrix-* lxpanel-pi wf-panel-pi lpplug-* wfplug-* ...
Pin-Priority: 990
```

This keeps Debian as the main source for the base system.

## Default session

The script intentionally writes a LightDM configuration using:

```ini
greeter-session=lightdm-gtk-greeter
user-session=rpd-x
```

This avoids the Labwc/Wayland greeter crash observed on generic amd64/VM tests.

## Local dummy packages

The script may create local dummy packages for:

```text
lpplug-netman
wfplug-netman
```

This is done only to satisfy meta-package dependencies when the real packages are missing or not installable on amd64. Network management is handled by Debian `network-manager-gnome` and `nm-applet`.

## NetworkManager migration

On Debian minimal/server installs, the primary NIC may be controlled by `/etc/network/interfaces`. NetworkManager then reports it as `unmanaged`, and the graphical applet shows only loopback.

When `--network-manager-takeover yes` is used, the script:

- backs up `/etc/network` and `/etc/NetworkManager`;
- reduces `/etc/network/interfaces` to loopback only;
- sets `[ifupdown] managed=true` for NetworkManager;
- creates or activates an Ethernet DHCP connection for the primary default-route interface.

The script skips this automatically when running over SSH and `--network-manager-takeover auto` is used.
