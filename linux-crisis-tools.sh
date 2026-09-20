#!/usr/bin/env bash
#
# linux-crisis-tools.sh
#
# Install a small, practical Linux troubleshooting toolbox.
#
# Supported package-manager families:
#   - Debian / Ubuntu / Linux Mint / Pop!_OS      (apt-get)
#   - Fedora / RHEL / Rocky / Alma / CentOS /
#     Amazon Linux                                (dnf or yum)
#   - openSUSE / SLES                             (zypper)
#   - Alpine                                      (apk)
#   - Arch / Manjaro                              (pacman, best effort)
#
# Safety properties:
#   - No curl|bash or remote code execution inside this script.
#   - No OS upgrade/dist-upgrade.
#   - No service enable/start/restart.
#   - Installs only from already configured OS package repositories.
#   - Installs packages one-by-one and skips failures/unavailable packages.
#   - Re-running is safe: already-installed packages are skipped.
#   - Advanced/kernel tracing tools are opt-in with --advanced.
#
# Usage:
#   sudo ./linux-crisis-tools.sh
#   sudo ./linux-crisis-tools.sh --advanced
#   ./linux-crisis-tools.sh --dry-run
#   ./linux-crisis-tools.sh --list
#   sudo ./linux-crisis-tools.sh --no-refresh
#

set -Eeuo pipefail
IFS=$'\n\t'

VERSION="1.0.0"
MODE="core"
DRY_RUN=0
REFRESH=1
LIST_ONLY=0

log()  { printf '[+] %s\n' "$*"; }
info() { printf '[i] %s\n' "$*"; }
warn() { printf '[!] %s\n' "$*" >&2; }
die()  { printf '[x] %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF'
linux-crisis-tools.sh

Usage:
  linux-crisis-tools.sh [OPTIONS]

Options:
  --core          Install core troubleshooting tools only (default)
  --advanced      Install core + advanced tracing/performance tools
  --dry-run       Print actions without changing the system
  --no-refresh    Do not refresh package metadata
  --list          Show packages selected for this OS and exit
  -h, --help      Show this help
  --version       Show version

Examples:
  sudo ./linux-crisis-tools.sh
  sudo ./linux-crisis-tools.sh --advanced
  ./linux-crisis-tools.sh --dry-run
EOF
}

while (($#)); do
  case "$1" in
    --core)       MODE="core" ;;
    --advanced)   MODE="advanced" ;;
    --dry-run)    DRY_RUN=1 ;;
    --no-refresh) REFRESH=0 ;;
    --list)       LIST_ONLY=1 ;;
    -h|--help)    usage; exit 0 ;;
    --version)    printf '%s\n' "$VERSION"; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
  shift
done

[[ "$(uname -s)" == "Linux" ]] || die "This script supports Linux only."
[[ -r /etc/os-release ]] || die "/etc/os-release not found."

# shellcheck disable=SC1091
. /etc/os-release

OS_ID="${ID:-unknown}"
OS_LIKE="${ID_LIKE:-}"
OS_NAME="${PRETTY_NAME:-$OS_ID}"

if (( EUID == 0 )); then
  SUDO=()
elif command -v sudo >/dev/null 2>&1; then
  SUDO=(sudo)
else
  die "Root privileges are required. Re-run as root or install sudo."
fi

run() {
  if (( DRY_RUN )); then
    printf '[dry-run] '
    printf '%q ' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

PM=""
if command -v apt-get >/dev/null 2>&1; then
  PM="apt"
elif command -v dnf >/dev/null 2>&1; then
  PM="dnf"
elif command -v yum >/dev/null 2>&1; then
  PM="yum"
elif command -v zypper >/dev/null 2>&1; then
  PM="zypper"
elif command -v apk >/dev/null 2>&1; then
  PM="apk"
elif command -v pacman >/dev/null 2>&1; then
  PM="pacman"
else
  die "No supported package manager found (apt-get/dnf/yum/zypper/apk/pacman)."
fi

# Package sets are intentionally conservative.
# Missing packages are skipped instead of aborting the whole run.
case "$PM" in
  apt)
    CORE_PKGS=(
      procps sysstat iproute2 iputils-ping dnsutils
      curl wget jq less lsof strace tcpdump ethtool
      mtr-tiny traceroute netcat-openbsd socat
      util-linux psmisc file openssl ca-certificates rsync
    )
    ADVANCED_PKGS=(
      ltrace iotop-c bpftrace bpfcc-tools
      blktrace numactl trace-cmd iperf3
    )
    ;;
  dnf|yum)
    CORE_PKGS=(
      procps-ng sysstat iproute iputils bind-utils
      curl wget jq less lsof strace tcpdump ethtool
      mtr traceroute nmap-ncat socat
      util-linux psmisc file openssl ca-certificates rsync
    )
    ADVANCED_PKGS=(
      ltrace iotop perf bpftrace bcc-tools
      blktrace numactl trace-cmd iperf3
    )
    ;;
  zypper)
    CORE_PKGS=(
      procps sysstat iproute2 iputils bind-utils
      curl wget jq less lsof strace tcpdump ethtool
      mtr traceroute netcat-openbsd socat
      util-linux psmisc file openssl ca-certificates rsync
    )
    ADVANCED_PKGS=(
      ltrace iotop perf bpftrace bcc-tools
      blktrace numactl trace-cmd iperf3
    )
    ;;
  apk)
    CORE_PKGS=(
      procps sysstat iproute2 iputils bind-tools
      curl wget jq less lsof strace tcpdump ethtool
      mtr traceroute netcat-openbsd socat
      util-linux psmisc file openssl ca-certificates rsync
    )
    ADVANCED_PKGS=(
      ltrace iotop perf bpftrace bcc-tools
      blktrace numactl trace-cmd iperf3
    )
    ;;
  pacman)
    CORE_PKGS=(
      procps-ng sysstat iproute2 iputils bind
      curl wget jq less lsof strace tcpdump ethtool
      mtr traceroute openbsd-netcat socat
      util-linux psmisc file openssl ca-certificates rsync
    )
    ADVANCED_PKGS=(
      ltrace iotop perf bpftrace bcc
      blktrace numactl trace-cmd iperf3
    )
    ;;
esac

if (( LIST_ONLY )); then
  printf 'OS:              %s\n' "$OS_NAME"
  printf 'Package manager: %s\n' "$PM"
  printf 'Mode:            %s\n\n' "$MODE"
  printf 'Core packages:\n'
  printf '  %s\n' "${CORE_PKGS[@]}"
  if [[ "$MODE" == "advanced" ]]; then
    printf '\nAdvanced packages:\n'
    printf '  %s\n' "${ADVANCED_PKGS[@]}"
    if [[ "$PM" == "apt" ]]; then
      printf '  %s\n' "linux-tools-common"
      printf '  %s\n' "linux-tools-$(uname -r) (best effort)"
    fi
  fi
  exit 0
fi

is_installed() {
  local pkg="$1"
  case "$PM" in
    apt)
      dpkg-query -W -f='${db:Status-Status}' "$pkg" 2>/dev/null | grep -q '^installed$'
      ;;
    dnf|yum|zypper)
      rpm -q "$pkg" >/dev/null 2>&1
      ;;
    apk)
      apk info -e "$pkg" >/dev/null 2>&1
      ;;
    pacman)
      pacman -Q "$pkg" >/dev/null 2>&1
      ;;
  esac
}

refresh_metadata() {
  (( REFRESH )) || { info "Package metadata refresh disabled."; return 0; }

  log "Refreshing package metadata only. No OS upgrade will be performed."
  case "$PM" in
    apt)
      if ! run "${SUDO[@]}" apt-get update; then
        warn "apt-get update failed; continuing with the existing package cache."
      fi
      ;;
    dnf)
      if ! run "${SUDO[@]}" dnf -y makecache; then
        warn "dnf makecache failed; continuing with existing metadata."
      fi
      ;;
    yum)
      if ! run "${SUDO[@]}" yum -y makecache; then
        warn "yum makecache failed; continuing with existing metadata."
      fi
      ;;
    zypper)
      if ! run "${SUDO[@]}" zypper --non-interactive refresh; then
        warn "zypper refresh failed; continuing with existing metadata."
      fi
      ;;
    apk)
      if ! run "${SUDO[@]}" apk update; then
        warn "apk update failed; continuing with existing metadata."
      fi
      ;;
    pacman)
      # Intentionally do NOT run `pacman -Sy`.
      # Arch does not support partial upgrades; refreshing the DB without
      # upgrading the system can leave package metadata inconsistent.
      warn "Arch/pacman: metadata refresh intentionally skipped."
      warn "Use a normally maintained/up-to-date Arch host before running this script."
      ;;
  esac
}

install_pkg() {
  local pkg="$1"

  if is_installed "$pkg"; then
    info "Already installed: $pkg"
    return 0
  fi

  log "Installing: $pkg"

  case "$PM" in
    apt)
      if ! run "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends "$pkg"; then
        warn "Could not install '$pkg' (missing package/repo/network?). Skipping."
      fi
      ;;
    dnf)
      if ! run "${SUDO[@]}" dnf install -y --setopt=install_weak_deps=False "$pkg"; then
        warn "Could not install '$pkg'. Skipping."
      fi
      ;;
    yum)
      if ! run "${SUDO[@]}" yum install -y "$pkg"; then
        warn "Could not install '$pkg'. Skipping."
      fi
      ;;
    zypper)
      if ! run "${SUDO[@]}" zypper --non-interactive install --no-recommends "$pkg"; then
        warn "Could not install '$pkg'. Skipping."
      fi
      ;;
    apk)
      if ! run "${SUDO[@]}" apk add "$pkg"; then
        warn "Could not install '$pkg'. Skipping."
      fi
      ;;
    pacman)
      if ! run "${SUDO[@]}" pacman -S --needed --noconfirm "$pkg"; then
        warn "Could not install '$pkg'. Skipping."
      fi
      ;;
  esac
}

install_apt_perf() {
  [[ "$PM" == "apt" ]] || return 0

  # On Debian/Ubuntu, perf commonly follows the running kernel package.
  install_pkg "linux-tools-common"

  local kernel_pkg="linux-tools-$(uname -r)"
  if ! is_installed "$kernel_pkg"; then
    log "Installing kernel-matched perf tools: $kernel_pkg"
    if ! run "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive \
      apt-get install -y --no-install-recommends "$kernel_pkg"; then
      warn "Kernel-matched linux-tools package unavailable for $(uname -r)."
      warn "perf may still be unavailable; this is non-fatal."
    fi
  else
    info "Already installed: $kernel_pkg"
  fi
}

verify_commands() {
  local core_cmds=(
    ps top vmstat
    iostat pidstat sar
    ip ss ping dig
    curl wget jq
    lsof strace tcpdump ethtool
    mtr traceroute nc socat
    lsblk findmnt fuser
    file openssl rsync
  )

  local advanced_cmds=(
    ltrace iotop perf bpftrace blktrace numactl trace-cmd iperf3
  )

  local missing=()
  local cmd

  printf '\n'
  log "Command verification"

  for cmd in "${core_cmds[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf '  [ok]      %s\n' "$cmd"
    else
      printf '  [missing] %s\n' "$cmd"
      missing+=("$cmd")
    fi
  done

  if [[ "$MODE" == "advanced" ]]; then
    for cmd in "${advanced_cmds[@]}"; do
      if command -v "$cmd" >/dev/null 2>&1; then
        printf '  [ok]      %s\n' "$cmd"
      else
        printf '  [missing] %s\n' "$cmd"
        missing+=("$cmd")
      fi
    done

    if [[ -d /usr/share/bcc/tools || -d /usr/share/bpfcc/tools ]]; then
      printf '  [ok]      BCC tools directory\n'
    else
      printf '  [missing] BCC tools directory\n'
    fi
  fi

  if ((${#missing[@]})); then
    warn "Some commands are unavailable on this distro/repository. This is non-fatal."
  fi
}

printf 'Linux Crisis Tools installer v%s\n' "$VERSION"
printf 'OS:              %s\n' "$OS_NAME"
printf 'ID / ID_LIKE:    %s / %s\n' "$OS_ID" "$OS_LIKE"
printf 'Kernel:          %s\n' "$(uname -r)"
printf 'Architecture:    %s\n' "$(uname -m)"
printf 'Package manager: %s\n' "$PM"
printf 'Mode:            %s\n' "$MODE"
printf 'Dry run:         %s\n\n' "$DRY_RUN"

refresh_metadata

for pkg in "${CORE_PKGS[@]}"; do
  install_pkg "$pkg"
done

if [[ "$MODE" == "advanced" ]]; then
  for pkg in "${ADVANCED_PKGS[@]}"; do
    install_pkg "$pkg"
  done
  install_apt_perf
fi

verify_commands

printf '\n'
log "Done."
info "No OS upgrade, service enable/start/restart, or configuration change was requested by this script."
info "For incident readiness, run this during provisioning, not for the first time during an outage."
