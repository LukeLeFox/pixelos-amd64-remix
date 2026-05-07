#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# RPD amd64 Post-Install
# ------------------------------------------------------------
# Transform a clean Debian 13 Trixie amd64 minimal/server install
# into a Raspberry Pi Desktop / PIXEL-like desktop using RPD packages.
#
# Tested target:
#   - Debian GNU/Linux 13 Trixie amd64
#   - Clean base install + SSH server
#   - Stable default session: rpd-x on X11
#
# Recommended first run:
#   sudo ./scripts/rpd-amd64-postinstall.sh --mode both --profile standard
#
# Safer first run:
#   sudo ./scripts/rpd-amd64-postinstall.sh --mode x11 --profile standard
# ============================================================

SCRIPT_VERSION="1.1.1"
LOG_FILE="/var/log/rpd-amd64-postinstall.log"
REPORT_DIR="/var/log/rpd-amd64-report"

RPI_SUITE="trixie"
RPI_KEYRING="/usr/share/keyrings/raspberrypi-archive-keyring.gpg"
RPI_SOURCE_LIST="/etc/apt/sources.list.d/raspberrypi-rpd.list"
RPI_PREFS="/etc/apt/preferences.d/90-raspberrypi-rpd-pin"

APT_SEQUOIA_POLICY_DIR="/etc/crypto-policies/back-ends"
APT_SEQUOIA_POLICY_FILE="${APT_SEQUOIA_POLICY_DIR}/apt-sequoia.config"
APT_SEQUOIA_DEFAULT_POLICY="/usr/share/apt/default-sequoia.config"
LEGACY_SHA1_UNTIL="2026-09-01"
ENABLE_SHA1_WORKAROUND=1

MODE=""
PROFILE=""
CLEANUP="safe"
DUMMY_NETMAN="auto"
DEFAULT_SESSION="rpd-x"
TARGET_USER=""
DRY_RUN=0
ALLOW_UNSUPPORTED=0
CONFIGURE_LIGHTDM=1
CONFIGURE_GRAPHICAL_TARGET=1
INSTALL_GNOME_KEYRING=1
FORCE_DUMMY=0
NO_REBOOT_PROMPT=0
NETWORK_MANAGER_TAKEOVER="auto"

DUMMY_VERSION="99.0-rpd-amd64dummy1"

trap 'echo "ERROR: Script failed at line ${LINENO}. Check ${LOG_FILE}" >&2' ERR

usage() {
  cat <<'USAGE'
Usage:
  sudo ./scripts/rpd-amd64-postinstall.sh [options]

Options:
  --mode x11|wayland|both
      Desktop stack to install. Interactive if omitted.
      Recommended: both, with X11 as default session.

  --profile minimal|standard|full
      minimal  = core desktop + theme + preferences
      standard = minimal + utilities + applications + graphics
      full     = standard + developer tools

  --cleanup safe|none
      safe hides/purges Raspberry Pi-specific extras where possible.
      Default: safe

  --default-session SESSION
      LightDM default session. Default: rpd-x
      Known useful values: rpd-x, LXDE, openbox, rpd-labwc
      Recommended for this amd64 remix: rpd-x

  --target-user USER
      User to add to desktop-related groups. Defaults to SUDO_USER.

  --legacy-sha1-until YYYY-MM-DD
      Temporary APT/Sequoia SHA1 compatibility date.
      Default: 2026-09-01

  --no-sha1-workaround
      Do not create the APT/Sequoia SHA1 compatibility override.
      Use only if archive.raspberrypi.com already verifies cleanly.

  --dummy-netman auto|yes|no
      auto creates local dummy packages for lpplug-netman/wfplug-netman
      only if they are missing or not installable on amd64.
      yes always creates/reinstalls them.
      no disables this workaround.
      Default: auto

  --network-manager-takeover auto|yes|no
      Configure NetworkManager to manage the primary interface so the LXDE/RPD
      network applet can see real interfaces instead of only loopback.
      auto applies the fix only when the primary interface is unmanaged and
      skips it when running over SSH. Default: auto

  --force-dummy
      Recreate/reinstall dummy lpplug-netman/wfplug-netman.

  --no-lightdm-config
      Do not overwrite LightDM configuration.

  --no-graphical-target
      Do not set graphical.target as default.

  --no-gnome-keyring
      Do not install gnome-keyring/libpam-gnome-keyring.

  --allow-unsupported
      Allow running outside Debian 13 Trixie amd64 at your own risk.

  --dry-run
      Print commands where possible without changing the system.

  --no-reboot-prompt
      Do not ask for reboot at the end.

  -h, --help
      Show this help.

Examples:
  sudo ./scripts/rpd-amd64-postinstall.sh --mode x11 --profile standard
  sudo ./scripts/rpd-amd64-postinstall.sh --mode both --profile standard
  sudo ./scripts/rpd-amd64-postinstall.sh --mode both --profile standard --network-manager-takeover yes
USAGE
}

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

run() {
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    printf '[DRY-RUN] '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "Run this script as root, for example: sudo $0" >&2
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode) MODE="${2:-}"; shift 2 ;;
      --profile) PROFILE="${2:-}"; shift 2 ;;
      --cleanup) CLEANUP="${2:-}"; shift 2 ;;
      --default-session) DEFAULT_SESSION="${2:-}"; shift 2 ;;
      --target-user) TARGET_USER="${2:-}"; shift 2 ;;
      --legacy-sha1-until) LEGACY_SHA1_UNTIL="${2:-}"; shift 2 ;;
      --no-sha1-workaround) ENABLE_SHA1_WORKAROUND=0; shift ;;
      --dummy-netman) DUMMY_NETMAN="${2:-}"; shift 2 ;;
      --network-manager-takeover) NETWORK_MANAGER_TAKEOVER="${2:-}"; shift 2 ;;
      --force-dummy) FORCE_DUMMY=1; shift ;;
      --no-lightdm-config) CONFIGURE_LIGHTDM=0; shift ;;
      --no-graphical-target) CONFIGURE_GRAPHICAL_TARGET=0; shift ;;
      --no-gnome-keyring) INSTALL_GNOME_KEYRING=0; shift ;;
      --allow-unsupported) ALLOW_UNSUPPORTED=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      --no-reboot-prompt) NO_REBOOT_PROMPT=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
  done
}

ask_choice() {
  local var_name="$1"
  local prompt="$2"
  shift 2
  local choices=("$@")
  local idx=1
  local answer=""

  echo
  echo "${prompt}"
  for item in "${choices[@]}"; do
    echo "  ${idx}) ${item}"
    idx=$((idx + 1))
  done

  while true; do
    read -rp "Choice [1-${#choices[@]}]: " answer
    if [[ "${answer}" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#choices[@]} )); then
      printf -v "${var_name}" '%s' "${choices[$((answer - 1))]}"
      break
    fi
    echo "Invalid choice."
  done
}

validate_choices() {
  if [[ -z "${MODE}" ]]; then
    ask_choice MODE "Select desktop stack:" "x11" "wayland" "both"
  fi

  if [[ -z "${PROFILE}" ]]; then
    ask_choice PROFILE "Select installation profile:" "minimal" "standard" "full"
  fi

  case "${MODE}" in
    x11|wayland|both) ;;
    *) echo "Invalid --mode: ${MODE}" >&2; exit 1 ;;
  esac

  case "${PROFILE}" in
    minimal|standard|full) ;;
    *) echo "Invalid --profile: ${PROFILE}" >&2; exit 1 ;;
  esac

  case "${CLEANUP}" in
    safe|none) ;;
    *) echo "Invalid --cleanup: ${CLEANUP}" >&2; exit 1 ;;
  esac

  case "${DUMMY_NETMAN}" in
    auto|yes|no) ;;
    *) echo "Invalid --dummy-netman: ${DUMMY_NETMAN}" >&2; exit 1 ;;
  esac

  case "${NETWORK_MANAGER_TAKEOVER}" in
    auto|yes|no) ;;
    *) echo "Invalid --network-manager-takeover: ${NETWORK_MANAGER_TAKEOVER}" >&2; exit 1 ;;
  esac

  if [[ ! "${LEGACY_SHA1_UNTIL}" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Invalid --legacy-sha1-until date: ${LEGACY_SHA1_UNTIL}. Expected YYYY-MM-DD." >&2
    exit 1
  fi

  if [[ -z "${DEFAULT_SESSION}" ]]; then
    echo "Invalid --default-session: empty value." >&2
    exit 1
  fi

  if [[ "${MODE}" == "wayland" && "${DEFAULT_SESSION}" == "rpd-x" ]]; then
    echo "Invalid combination: --mode wayland does not install rpd-x." >&2
    echo "Use --default-session rpd-labwc, or use --mode both / --mode x11." >&2
    exit 1
  fi
}

setup_logging() {
  if [[ "${DRY_RUN}" -eq 0 ]]; then
    touch "${LOG_FILE}"
    chmod 0644 "${LOG_FILE}"
    exec > >(tee -a "${LOG_FILE}") 2>&1
  fi
}

check_platform() {
  local arch=""
  arch="$(dpkg --print-architecture)"

  if [[ "${arch}" != "amd64" ]]; then
    echo "This script is intended for Debian amd64. Detected architecture: ${arch}" >&2
    if [[ "${ALLOW_UNSUPPORTED}" -ne 1 ]]; then
      echo "Use --allow-unsupported to continue anyway." >&2
      exit 1
    fi
  fi

  . /etc/os-release

  if [[ "${ID:-unknown}" != "debian" ]]; then
    echo "This script is intended for Debian. Detected OS: ${ID:-unknown}" >&2
    if [[ "${ALLOW_UNSUPPORTED}" -ne 1 ]]; then
      echo "Use --allow-unsupported to continue anyway." >&2
      exit 1
    fi
  fi

  if [[ "${VERSION_CODENAME:-unknown}" != "${RPI_SUITE}" ]]; then
    echo "This script targets Debian ${RPI_SUITE}. Detected codename: ${VERSION_CODENAME:-unknown}" >&2
    if [[ "${ALLOW_UNSUPPORTED}" -ne 1 ]]; then
      echo "Install Debian ${RPI_SUITE} or use --allow-unsupported at your own risk." >&2
      exit 1
    fi
  fi
}

install_prerequisites() {
  log "Installing base prerequisites..."
  run apt-get update || true

  local packages=(
    ca-certificates curl gpg apt-transport-https dpkg-dev systemd dbus
  )

  run apt-get install -y "${packages[@]}"
}

configure_apt_sequoia_sha1_policy() {
  if [[ "${ENABLE_SHA1_WORKAROUND}" -ne 1 ]]; then
    log "APT/Sequoia SHA1 compatibility workaround disabled."
    return 0
  fi

  log "Applying temporary APT/Sequoia SHA1 compatibility policy until ${LEGACY_SHA1_UNTIL}..."
  log "This is a compatibility workaround for legacy third-party repository key signatures."

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] create/update ${APT_SEQUOIA_POLICY_FILE}"
    return 0
  fi

  install -d -m 0755 "${APT_SEQUOIA_POLICY_DIR}"

  if [[ -f "${APT_SEQUOIA_DEFAULT_POLICY}" ]]; then
    cp "${APT_SEQUOIA_DEFAULT_POLICY}" "${APT_SEQUOIA_POLICY_FILE}"
  else
    cat > "${APT_SEQUOIA_POLICY_FILE}" <<'EOF_POLICY'
[hash_algorithms]
sha1.second_preimage_resistance = 2026-02-01
EOF_POLICY
  fi

  if grep -q '^sha1\.second_preimage_resistance' "${APT_SEQUOIA_POLICY_FILE}"; then
    sed -i "s/^sha1\.second_preimage_resistance.*/sha1.second_preimage_resistance = ${LEGACY_SHA1_UNTIL}/" "${APT_SEQUOIA_POLICY_FILE}"
  else
    if ! grep -q '^\[hash_algorithms\]' "${APT_SEQUOIA_POLICY_FILE}"; then
      printf '\n[hash_algorithms]\n' >> "${APT_SEQUOIA_POLICY_FILE}"
    fi

    awk -v date="${LEGACY_SHA1_UNTIL}" '
      /^\[hash_algorithms\]/ && !done {
        print
        print "sha1.second_preimage_resistance = " date
        done=1
        next
      }
      { print }
    ' "${APT_SEQUOIA_POLICY_FILE}" > "${APT_SEQUOIA_POLICY_FILE}.tmp"

    mv "${APT_SEQUOIA_POLICY_FILE}.tmp" "${APT_SEQUOIA_POLICY_FILE}"
  fi

  chmod 0644 "${APT_SEQUOIA_POLICY_FILE}"
}

configure_raspberrypi_repo() {
  log "Configuring Raspberry Pi archive repository for ${RPI_SUITE}/amd64..."

  run install -d -m 0755 /usr/share/keyrings

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] download and dearmor Raspberry Pi archive key to ${RPI_KEYRING}"
  else
    curl -fsSL https://archive.raspberrypi.com/debian/raspberrypi.gpg.key \
      | gpg --dearmor -o "${RPI_KEYRING}.tmp"
    mv "${RPI_KEYRING}.tmp" "${RPI_KEYRING}"
    chmod 0644 "${RPI_KEYRING}"
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] write ${RPI_SOURCE_LIST}"
    echo "deb [arch=amd64 signed-by=${RPI_KEYRING}] https://archive.raspberrypi.com/debian/ ${RPI_SUITE} main"
  else
    cat > "${RPI_SOURCE_LIST}" <<EOF_SRC
# Raspberry Pi Desktop packages for Debian amd64 remix
# Managed by rpd-amd64-postinstall.sh
deb [arch=amd64 signed-by=${RPI_KEYRING}] https://archive.raspberrypi.com/debian/ ${RPI_SUITE} main
EOF_SRC
  fi
}

configure_raspberrypi_pinning() {
  log "Writing safe APT pinning in ${RPI_PREFS}..."

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] write ${RPI_PREFS}"
    return 0
  fi

  cat > "${RPI_PREFS}" <<'EOF_PREF'
# Prefer Debian for the base OS. Only selected Raspberry Pi Desktop packages
# should come from archive.raspberrypi.com unless explicitly required.
Package: *
Pin: origin "archive.raspberrypi.com"
Pin-Priority: 100

# Raspberry Pi Desktop / RPD package families and direct dependencies needed
# by the desktop meta-packages on Debian amd64.
Package: rpd-* pixtrix-* lxpanel-pi wf-panel-pi lpplug-* wfplug-* raspi-config rc-gui rpcc pipanel raindrop rasputin rpinters rp-prefapps pi-* rpi-* agnostics piclone merp autotouch labwc wayvnc realvnc-vnc-server libnma0 libnma-common gir1.2-nma-1.0
Pin: origin "archive.raspberrypi.com"
Pin-Priority: 990
EOF_PREF
}

apt_update_after_repo() {
  log "Running apt update after repository/pinning configuration..."
  run apt-get update
}

package_is_installable() {
  local package="$1"
  apt-get -s install "${package}" >/dev/null 2>&1
}

build_local_dummy_package() {
  local package="$1"
  local workdir="/tmp/rpd-amd64-dummy-${package}"
  local deb="/tmp/${package}_${DUMMY_VERSION}_all.deb"

  if [[ "${FORCE_DUMMY}" -ne 1 ]]; then
    if dpkg-query -W -f='${Status} ${Version}' "${package}" 2>/dev/null | grep -q "install ok installed ${DUMMY_VERSION}"; then
      log "Dummy package already installed: ${package} ${DUMMY_VERSION}"
      return 0
    fi
  fi

  log "Creating local dummy package for ${package}..."

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] build and install ${deb}"
    return 0
  fi

  rm -rf "${workdir}"
  install -d -m 0755 "${workdir}/DEBIAN"
  install -d -m 0755 "${workdir}/usr/share/doc/${package}"

  cat > "${workdir}/DEBIAN/control" <<EOF_DUMMY
Package: ${package}
Version: ${DUMMY_VERSION}
Section: misc
Priority: optional
Architecture: all
Maintainer: Local Administrator <root@localhost>
Description: Local dummy package for Raspberry Pi Desktop amd64 remix
 This dummy package satisfies the Raspberry Pi Desktop metapackage dependency
 on ${package} when the real package is unavailable or not installable on amd64.
 Network management is provided by Debian's network-manager-gnome/nm-applet.
EOF_DUMMY

  cat > "${workdir}/usr/share/doc/${package}/README.rpd-amd64-dummy" <<EOF_README
This is a local dummy package generated by rpd-amd64-postinstall.sh.

Reason:
  Raspberry Pi Desktop metapackages depend on ${package}, but the package may
  be missing or not installable on Debian amd64 from archive.raspberrypi.com.

Replacement:
  Network management is handled by Debian's NetworkManager tools, especially
  network-manager-gnome/nm-applet.

To inspect:
  dpkg -s ${package}

To remove later:
  sudo dpkg -r ${package}
EOF_README

  dpkg-deb --build "${workdir}" "${deb}" >/dev/null
  dpkg -i "${deb}"
}

ensure_netman_dependencies() {
  if [[ "${DUMMY_NETMAN}" == "no" ]]; then
    log "Dummy netman packages disabled."
    return 0
  fi

  local needed=()
  case "${MODE}" in
    x11) needed+=(lpplug-netman) ;;
    wayland) needed+=(wfplug-netman) ;;
    both) needed+=(lpplug-netman wfplug-netman) ;;
  esac

  local package=""
  for package in "${needed[@]}"; do
    if [[ "${DUMMY_NETMAN}" == "yes" ]]; then
      build_local_dummy_package "${package}"
      continue
    fi

    if package_is_installable "${package}"; then
      log "${package} appears installable from configured repositories. No dummy needed."
    else
      log "${package} is missing or not installable on this amd64 system. Using local dummy package."
      build_local_dummy_package "${package}"
    fi
  done
}

build_package_list() {
  RPD_PACKAGES=()
  BASE_PACKAGES=(
    lightdm lightdm-gtk-greeter
    xserver-xorg xserver-xorg-core xserver-xorg-video-all xserver-xorg-input-all xinit
    accountsservice network-manager network-manager-gnome
    dbus-x11 dbus-user-session polkitd
    pipewire pipewire-pulse wireplumber pavucontrol
    avahi-daemon fonts-noto-color-emoji fastfetch xterm
  )

  if [[ "${INSTALL_GNOME_KEYRING}" -eq 1 ]]; then
    BASE_PACKAGES+=(gnome-keyring libpam-gnome-keyring)
  fi

  case "${MODE}" in
    x11) RPD_PACKAGES+=(rpd-x-core rpd-x-extras) ;;
    wayland) RPD_PACKAGES+=(rpd-wayland-core rpd-wayland-extras) ;;
    both) RPD_PACKAGES+=(rpd-x-core rpd-x-extras rpd-wayland-core rpd-wayland-extras) ;;
  esac

  RPD_PACKAGES+=(rpd-theme rpd-preferences)

  case "${PROFILE}" in
    minimal) ;;
    standard) RPD_PACKAGES+=(rpd-utilities rpd-applications rpd-graphics) ;;
    full) RPD_PACKAGES+=(rpd-utilities rpd-applications rpd-graphics rpd-developer) ;;
  esac
}

install_desktop() {
  build_package_list

  log "Installing base desktop support packages..."
  run apt-get install -y "${BASE_PACKAGES[@]}"

  ensure_netman_dependencies

  log "Installing Raspberry Pi Desktop packages: mode=${MODE}, profile=${PROFILE}"
  run apt-get install -y -o APT::Install-Recommends=true "${RPD_PACKAGES[@]}"
}

fix_runtime_dirs() {
  log "Ensuring LightDM runtime/data directories and utmp exist..."

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] create /var/lib/lightdm/data and /run/utmp"
    return 0
  fi

  install -d -m 0755 /var/lib/lightdm
  install -d -m 0755 /var/lib/lightdm/data

  if id lightdm >/dev/null 2>&1; then
    chown -R lightdm:lightdm /var/lib/lightdm/data || true
  fi

  touch /run/utmp || true
  if getent group utmp >/dev/null 2>&1; then
    chown root:utmp /run/utmp || true
  else
    chown root:root /run/utmp || true
  fi
  chmod 0664 /run/utmp || true

  systemctl restart systemd-update-utmp.service 2>/dev/null || true
}

backup_lightdm_config() {
  local backup_dir="/root/lightdm-backup-rpd-amd64-$(date +%F-%H%M%S)"
  log "Backing up existing LightDM configuration to ${backup_dir}..."

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] backup /etc/lightdm to ${backup_dir}"
    return 0
  fi

  install -d -m 0700 "${backup_dir}"
  cp -a /etc/lightdm "${backup_dir}/" 2>/dev/null || true
}

configure_lightdm_x11_default() {
  if [[ "${CONFIGURE_LIGHTDM}" -ne 1 ]]; then
    log "LightDM configuration disabled."
    return 0
  fi

  log "Configuring LightDM with stable greeter and default session: ${DEFAULT_SESSION}"
  backup_lightdm_config

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] write /etc/lightdm/lightdm.conf and disable local conf.d files"
    return 0
  fi

  install -d -m 0755 /etc/lightdm
  install -d -m 0755 /etc/lightdm/lightdm.conf.d
  install -d -m 0755 /etc/lightdm/disabled-conf.d

  find /etc/lightdm/lightdm.conf.d -maxdepth 1 -type f -name '*.conf' -print0 2>/dev/null \
    | while IFS= read -r -d '' file; do
        mv "${file}" "/etc/lightdm/disabled-conf.d/$(basename "${file}").disabled.$(date +%F-%H%M%S)"
      done

  cat > /etc/lightdm/lightdm.conf <<EOF_LIGHTDM
[LightDM]
start-default-seat=true

[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=${DEFAULT_SESSION}
autologin-user=
autologin-user-timeout=0
EOF_LIGHTDM

  cat > /etc/lightdm/lightdm.conf.d/99-rpd-amd64-default.conf <<EOF_SNIPPET
# Managed by rpd-amd64-postinstall.sh
[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=${DEFAULT_SESSION}
autologin-user=
autologin-user-timeout=0
EOF_SNIPPET
}

configure_network_manager_takeover() {
  if [[ "${NETWORK_MANAGER_TAKEOVER}" == "no" ]]; then
    log "NetworkManager takeover disabled."
    return 0
  fi

  if ! command -v nmcli >/dev/null 2>&1; then
    log "nmcli not found; skipping NetworkManager takeover."
    return 0
  fi

  local primary_iface=""
  primary_iface="$(ip route show default 2>/dev/null | awk '{print $5; exit}')"

  if [[ -z "${primary_iface}" || "${primary_iface}" == "lo" ]]; then
    log "No primary non-loopback interface detected; skipping NetworkManager takeover."
    return 0
  fi

  local nm_state=""
  nm_state="$(nmcli -t -f DEVICE,STATE device status 2>/dev/null | awk -F: -v dev="${primary_iface}" '$1 == dev {print $2; exit}')"

  log "Primary interface: ${primary_iface}; NetworkManager state: ${nm_state:-unknown}"

  if [[ "${NETWORK_MANAGER_TAKEOVER}" == "auto" && -n "${SSH_CONNECTION:-}" ]]; then
    log "SSH session detected and takeover=auto; skipping to avoid dropping remote access."
    log "Run again locally with --network-manager-takeover yes if you want to migrate networking to NetworkManager."
    return 0
  fi

  if [[ "${NETWORK_MANAGER_TAKEOVER}" == "auto" && "${nm_state}" != "unmanaged" ]]; then
    log "Primary interface is not unmanaged; no NetworkManager takeover needed."
    return 0
  fi

  log "Configuring NetworkManager to manage ${primary_iface}..."

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] backup ifupdown config, set NM managed=true, restart NetworkManager, create DHCP connection if needed"
    return 0
  fi

  local backup_dir="/root/network-backup-rpd-amd64-$(date +%F-%H%M%S)"
  install -d -m 0700 "${backup_dir}"
  cp -a /etc/network "${backup_dir}/network" 2>/dev/null || true
  cp -a /etc/NetworkManager "${backup_dir}/NetworkManager" 2>/dev/null || true

  if [[ -f /etc/network/interfaces ]] && grep -Eq "(auto|allow-hotplug|iface)[[:space:]].*${primary_iface}" /etc/network/interfaces; then
    log "Moving ${primary_iface} away from /etc/network/interfaces management. Backup: ${backup_dir}"
    cat > /etc/network/interfaces <<'EOF_INTERFACES'
# Managed by rpd-amd64-postinstall.sh
# Network interfaces are managed by NetworkManager.

auto lo
iface lo inet loopback
EOF_INTERFACES
  fi

  if [[ -d /etc/network/interfaces.d ]]; then
    local disabled_dir="/etc/network/interfaces.d.disabled-rpd-amd64"
    install -d -m 0755 "${disabled_dir}"
    while IFS= read -r file; do
      [[ -f "${file}" ]] || continue
      if grep -q "${primary_iface}" "${file}"; then
        log "Disabling ifupdown snippet for ${primary_iface}: ${file}"
        mv "${file}" "${disabled_dir}/$(basename "${file}").disabled.$(date +%F-%H%M%S)"
      fi
    done < <(find /etc/network/interfaces.d -maxdepth 1 -type f 2>/dev/null)
  fi

  install -d -m 0755 /etc/NetworkManager/conf.d
  cat > /etc/NetworkManager/conf.d/10-rpd-amd64-managed.conf <<'EOF_NM'
# Managed by rpd-amd64-postinstall.sh
[ifupdown]
managed=true

[keyfile]
unmanaged-devices=none
EOF_NM

  systemctl enable NetworkManager.service
  systemctl restart NetworkManager.service
  sleep 2

  nmcli device set "${primary_iface}" managed yes 2>/dev/null || true

  if ! nmcli -t -f NAME,DEVICE connection show --active 2>/dev/null | grep -q ":${primary_iface}$"; then
    local con_name="Wired connection ${primary_iface}"
    if ! nmcli -t -f NAME connection show 2>/dev/null | grep -qxF "${con_name}"; then
      nmcli connection add type ethernet ifname "${primary_iface}" con-name "${con_name}" ipv4.method auto ipv6.method auto autoconnect yes || true
    fi
    nmcli connection up "${con_name}" || nmcli device connect "${primary_iface}" || true
  fi
}

configure_services() {
  log "Configuring services..."
  run systemctl enable NetworkManager.service
  run systemctl enable avahi-daemon.service
  run systemctl enable lightdm.service

  if [[ "${CONFIGURE_GRAPHICAL_TARGET}" -eq 1 ]]; then
    run systemctl set-default graphical.target
  fi

  run systemctl daemon-reload
}

configure_user_groups() {
  if [[ -z "${TARGET_USER}" ]]; then
    TARGET_USER="${SUDO_USER:-}"
  fi

  if [[ -z "${TARGET_USER}" || "${TARGET_USER}" == "root" ]]; then
    echo
    read -rp "Enter the normal desktop username to configure groups, or leave empty to skip: " TARGET_USER || true
  fi

  if [[ -z "${TARGET_USER}" ]]; then
    log "Skipping user group configuration."
    return 0
  fi

  if ! id "${TARGET_USER}" >/dev/null 2>&1; then
    echo "User not found: ${TARGET_USER}. Skipping group configuration." >&2
    return 0
  fi

  local groups_to_add=(audio video plugdev netdev bluetooth lpadmin scanner)
  local existing_groups=()
  local group=""

  for group in "${groups_to_add[@]}"; do
    if getent group "${group}" >/dev/null 2>&1; then
      existing_groups+=("${group}")
    fi
  done

  if [[ "${#existing_groups[@]}" -gt 0 ]]; then
    log "Adding ${TARGET_USER} to groups: ${existing_groups[*]}"
    run usermod -aG "$(IFS=,; echo "${existing_groups[*]}")" "${TARGET_USER}"
  fi
}

hide_desktop_entry() {
  local file="$1"
  [[ -f "${file}" ]] || return 0
  log "Hiding menu entry: ${file}"

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] set NoDisplay=true in ${file}"
    return 0
  fi

  if grep -q '^NoDisplay=' "${file}"; then
    sed -i 's/^NoDisplay=.*/NoDisplay=true/' "${file}"
  else
    printf '\nNoDisplay=true\n' >> "${file}"
  fi
}

hide_rpi_specific_menu_entries() {
  log "Hiding Raspberry Pi-specific menu entries where present..."

  local candidates=(
    /usr/share/applications/raspi-config.desktop
    /usr/share/applications/rc_gui.desktop
    /usr/share/applications/raspberry-pi-configuration.desktop
    /usr/share/applications/piclone.desktop
    /usr/share/applications/rpi-imager.desktop
    /usr/share/applications/rpi-connect.desktop
    /usr/share/applications/rp-bookshelf.desktop
    /usr/share/applications/rpi-bookshelf.desktop
    /usr/share/applications/piwiz.desktop
    /usr/share/applications/agnostics.desktop
  )

  local file=""
  for file in "${candidates[@]}"; do
    hide_desktop_entry "${file}"
  done
}

safe_purge_package() {
  local package="$1"

  if ! dpkg-query -W -f='${Status}' "${package}" 2>/dev/null | grep -q "install ok installed"; then
    return 0
  fi

  log "Checking whether ${package} can be safely purged..."

  local simulation=""
  simulation="$(apt-get -s purge "${package}" || true)"

  if echo "${simulation}" | grep -Eq 'Remv (rpd-|labwc|wf-panel-pi|lxpanel-pi|openbox|lightdm|network-manager|xserver-xorg)'; then
    log "Skipping purge of ${package}: it would remove desktop-critical packages."
    return 0
  fi

  log "Purging ${package}..."
  run apt-get purge -y "${package}"
}

safe_cleanup() {
  if [[ "${CLEANUP}" != "safe" ]]; then
    log "Cleanup disabled."
    return 0
  fi

  hide_rpi_specific_menu_entries
  log "Purging non-essential Raspberry Pi-specific extras where safe..."

  local purge_candidates=(
    piclone rpi-imager rp-bookshelf rpi-userguide piwiz agnostics rpi-connect
    python3-rpi.gpio python3-gpiozero pigpio python3-pigpio
    raspi-firmware libraspberrypi-bin libraspberrypi0
  )

  local package=""
  for package in "${purge_candidates[@]}"; do
    safe_purge_package "${package}"
  done

  run apt-get autoremove -y
  run apt-get clean
}

create_report() {
  log "Creating final installation report in ${REPORT_DIR}..."

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY-RUN] create report under ${REPORT_DIR}"
    return 0
  fi

  install -d -m 0755 "${REPORT_DIR}"

  {
    echo "RPD amd64 Post-Install Report"
    echo "=============================="
    echo "Date:              $(date -Is)"
    echo "Script version:    ${SCRIPT_VERSION}"
    echo "Mode:              ${MODE}"
    echo "Profile:           ${PROFILE}"
    echo "Cleanup:           ${CLEANUP}"
    echo "Default session:   ${DEFAULT_SESSION}"
    echo "Dummy netman:      ${DUMMY_NETMAN}"
    echo "NM takeover:       ${NETWORK_MANAGER_TAKEOVER}"
    echo "SHA1 workaround:   ${ENABLE_SHA1_WORKAROUND}"
    echo "SHA1 until:        ${LEGACY_SHA1_UNTIL}"
    echo "Log file:          ${LOG_FILE}"
    echo
    echo "OS release:"
    cat /etc/os-release 2>/dev/null || true
    echo
    echo "Architecture:"
    dpkg --print-architecture 2>/dev/null || true
    echo
    echo "Kernel:"
    uname -a 2>/dev/null || true
    echo
    echo "Systemd default target:"
    systemctl get-default 2>/dev/null || true
    echo
    echo "LightDM status:"
    systemctl status lightdm --no-pager 2>/dev/null || true
    echo
    echo "Session files:"
    ls -la /usr/share/xsessions /usr/share/wayland-sessions 2>/dev/null || true
    echo
    echo "RPD package policy:"
    apt-cache policy rpd-x-core rpd-wayland-core rpd-theme libnma0 libnma-common 2>/dev/null || true
    echo
    echo "Netman / NetworkManager packages:"
    dpkg -l | grep -E 'lpplug-netman|wfplug-netman|network-manager-gnome' || true
    echo
    echo "NetworkManager devices:"
    nmcli device status 2>/dev/null || true
  } > "${REPORT_DIR}/summary.txt"

  dpkg -l > "${REPORT_DIR}/dpkg-list.txt"
  apt-mark showmanual > "${REPORT_DIR}/apt-manual.txt" 2>/dev/null || true
  cp -a /etc/lightdm "${REPORT_DIR}/lightdm-config" 2>/dev/null || true
  cp -a "${RPI_SOURCE_LIST}" "${REPORT_DIR}/raspberrypi-rpd.list" 2>/dev/null || true
  cp -a "${RPI_PREFS}" "${REPORT_DIR}/90-raspberrypi-rpd-pin" 2>/dev/null || true
  cp -a "${APT_SEQUOIA_POLICY_FILE}" "${REPORT_DIR}/apt-sequoia.config" 2>/dev/null || true
}

print_summary() {
  echo
  echo "============================================================"
  echo "RPD amd64 post-install completed"
  echo "============================================================"
  echo "Script version:      ${SCRIPT_VERSION}"
  echo "Mode:                ${MODE}"
  echo "Profile:             ${PROFILE}"
  echo "Cleanup:             ${CLEANUP}"
  echo "Default session:     ${DEFAULT_SESSION}"
  echo "Dummy netman:        ${DUMMY_NETMAN}"
  echo "NM takeover:         ${NETWORK_MANAGER_TAKEOVER}"
  echo "Log file:            ${LOG_FILE}"
  echo "Report dir:          ${REPORT_DIR}"

  if [[ "${ENABLE_SHA1_WORKAROUND}" -eq 1 ]]; then
    echo "SHA1 workaround:     enabled until ${LEGACY_SHA1_UNTIL}"
    echo "Override file:       ${APT_SEQUOIA_POLICY_FILE}"
  else
    echo "SHA1 workaround:     disabled"
  fi

  echo
  echo "Recommended checks after reboot:"
  echo "  echo \$DESKTOP_SESSION"
  echo "  echo \$XDG_SESSION_TYPE"
  echo "  nmcli device status"
  echo "  systemctl status lightdm --no-pager"
  echo "  cat ${REPORT_DIR}/summary.txt"
  echo
  echo "Expected stable values:"
  echo "  DESKTOP_SESSION=${DEFAULT_SESSION}"
  echo "  XDG_SESSION_TYPE=x11 when using rpd-x"
  echo
  echo "To remove the temporary SHA1 compatibility override later:"
  echo "  sudo rm -f ${APT_SEQUOIA_POLICY_FILE}"
  echo "  sudo apt update"
  echo
}

prompt_reboot() {
  if [[ "${NO_REBOOT_PROMPT}" -eq 1 || "${DRY_RUN}" -eq 1 ]]; then
    return 0
  fi

  echo
  read -rp "Reboot now? [y/N]: " answer || true
  case "${answer:-}" in
    y|Y|yes|YES) log "Reboot requested by user."; reboot ;;
    *) log "Reboot skipped by user." ;;
  esac
}

main() {
  parse_args "$@"
  require_root
  validate_choices
  setup_logging

  log "Starting RPD amd64 post-install v${SCRIPT_VERSION}."
  log "Mode=${MODE}, Profile=${PROFILE}, Cleanup=${CLEANUP}, Default session=${DEFAULT_SESSION}, Dry-run=${DRY_RUN}"

  check_platform
  install_prerequisites
  configure_apt_sequoia_sha1_policy
  configure_raspberrypi_repo
  configure_raspberrypi_pinning
  apt_update_after_repo
  install_desktop
  fix_runtime_dirs
  configure_lightdm_x11_default
  configure_network_manager_takeover
  configure_services
  configure_user_groups
  safe_cleanup
  create_report
  print_summary
  prompt_reboot
}

main "$@"
