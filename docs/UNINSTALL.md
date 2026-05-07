# Uninstall / rollback notes

This project modifies APT sources, APT preferences, LightDM configuration, and optionally NetworkManager/ifupdown configuration.

There is no fully automatic rollback yet. Use a VM snapshot when testing.

## Remove Raspberry Pi archive configuration

```bash
sudo rm -f /etc/apt/sources.list.d/raspberrypi-rpd.list
sudo rm -f /etc/apt/preferences.d/90-raspberrypi-rpd-pin
sudo rm -f /usr/share/keyrings/raspberrypi-archive-keyring.gpg
sudo apt update
```

## Remove APT/Sequoia SHA1 compatibility override

```bash
sudo rm -f /etc/crypto-policies/back-ends/apt-sequoia.config
sudo apt update
```

## Remove local dummy packages

```bash
sudo dpkg -r lpplug-netman wfplug-netman 2>/dev/null || true
```

## Restore LightDM configuration

The installer backs up LightDM configuration under `/root/lightdm-backup-rpd-amd64-*`.

Example:

```bash
sudo systemctl stop lightdm
sudo cp -a /root/lightdm-backup-rpd-amd64-YYYY-MM-DD-HHMMSS/lightdm/* /etc/lightdm/
sudo systemctl restart lightdm
```

## Remove RPD packages

Review before executing:

```bash
apt list --installed | grep -E 'rpd-|pixtrix|lxpanel-pi|wf-panel-pi'
```

Possible removal command:

```bash
sudo apt purge 'rpd-*' 'pixtrix-*' lxpanel-pi wf-panel-pi
sudo apt autoremove
```

Do not run this blindly on a system you care about.
