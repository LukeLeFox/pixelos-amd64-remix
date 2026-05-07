# Troubleshooting

## Black screen or blinking cursor after boot

Switch to a TTY:

```text
Ctrl + Alt + F2
```

Check LightDM:

```bash
sudo systemctl status lightdm --no-pager
sudo journalctl -b -u lightdm --no-pager -n 200
sudo tail -n 200 /var/log/lightdm/lightdm.log
```

Force the stable X11 session:

```bash
sudo systemctl stop lightdm || true
sudo mkdir -p /etc/lightdm/lightdm.conf.d

sudo tee /etc/lightdm/lightdm.conf > /dev/null <<'EOF_LIGHTDM'
[LightDM]
start-default-seat=true

[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=rpd-x
autologin-user=
autologin-user-timeout=0
EOF_LIGHTDM

sudo systemctl restart lightdm
```

If `rpd-x` still fails, try the LXDE fallback:

```bash
sudo sed -i 's/^user-session=.*/user-session=LXDE/' /etc/lightdm/lightdm.conf
sudo systemctl restart lightdm
```

## LightDM tries to start Labwc/Wayland

Look for entries forcing `rpd-labwc`, `labwc-pi` or autologin:

```bash
grep -R "autologin\|labwc\|rpd-labwc\|greeter-session\|user-session" \
  /etc/lightdm /usr/share/lightdm/lightdm.conf.d 2>/dev/null
```

The stable default should be:

```ini
[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=rpd-x
```

## The network applet shows only loopback

Check whether NetworkManager sees the real NIC:

```bash
nmcli device status
ip route show default
ip a
```

If the primary NIC is `unmanaged`, run from local console:

```bash
sudo ./scripts/rpd-amd64-postinstall.sh \
  --mode both \
  --profile standard \
  --network-manager-takeover yes \
  --no-reboot-prompt
```

Then reboot:

```bash
sudo reboot
```

## APT complains about SHA1 / Sequoia / repository not signed

The script normally handles this with the temporary compatibility override:

```bash
--legacy-sha1-until 2026-09-01
```

Verify the override exists:

```bash
cat /etc/crypto-policies/back-ends/apt-sequoia.config
```

Remove it later when the third-party repository verifies cleanly:

```bash
sudo rm -f /etc/crypto-policies/back-ends/apt-sequoia.config
sudo apt update
```

## Collect diagnostics

```bash
sudo ./scripts/rpd-amd64-diagnose.sh
```

Attach the generated `.tar.gz` archive when opening an issue.
