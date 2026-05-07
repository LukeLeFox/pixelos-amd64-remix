#!/usr/bin/env bash
set -Eeuo pipefail

OUT_DIR="${1:-/tmp/rpd-amd64-diagnostics-$(date +%F-%H%M%S)}"
mkdir -p "${OUT_DIR}"

run_capture() {
  local name="$1"
  shift
  echo "# $*" > "${OUT_DIR}/${name}.txt"
  "$@" >> "${OUT_DIR}/${name}.txt" 2>&1 || true
}

run_capture os-release cat /etc/os-release
run_capture uname uname -a
run_capture architecture dpkg --print-architecture
run_capture default-target systemctl get-default
run_capture lightdm-status systemctl status lightdm --no-pager
run_capture lightdm-journal journalctl -b -u lightdm --no-pager -n 250
run_capture lightdm-log tail -n 250 /var/log/lightdm/lightdm.log
run_capture sessions bash -lc 'ls -la /usr/share/xsessions /usr/share/wayland-sessions 2>/dev/null; for f in /usr/share/xsessions/*.desktop /usr/share/wayland-sessions/*.desktop; do [ -f "$f" ] || continue; echo "---- $f"; grep -E "^(Name|Exec|TryExec)=" "$f" || true; done'
run_capture network-ip ip a
run_capture network-routes ip route
run_capture nmcli-device nmcli device status
run_capture nmcli-connections nmcli connection show
run_capture apt-policy apt-cache policy rpd-x-core rpd-wayland-core rpd-theme libnma0 libnma-common lpplug-netman wfplug-netman
run_capture rpi-files bash -lc 'find /usr/share -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | grep -Ei "rpd|wallpaper|background|pix|raspberry" || true'
run_capture rpd-report bash -lc 'cat /var/log/rpd-amd64-report/summary.txt 2>/dev/null || true'

tarball="${OUT_DIR}.tar.gz"
tar -czf "${tarball}" -C "$(dirname "${OUT_DIR}")" "$(basename "${OUT_DIR}")"

echo "Diagnostics collected in: ${OUT_DIR}"
echo "Archive: ${tarball}"
