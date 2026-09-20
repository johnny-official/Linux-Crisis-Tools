# Linux Crisis Tools

A small, distro-aware installer for Linux troubleshooting tools that you want available **before** an incident happens.

The goal is simple: when a VPS is slow, unreachable, dropping packets, exhausting memory, or suffering disk I/O problems, you should not first have to remember package names or build a debugging toolbox from scratch.

Inspired by Brendan Gregg's article, [Linux Crisis Tools](https://www.brendangregg.com/blog/2024-03-24/linux-crisis-tools.html).

## Why this exists

During an incident, installing diagnostic tools may fail because:

- DNS is broken
- outbound HTTP/HTTPS is blocked
- package repositories are unavailable
- the filesystem is read-only
- the server has no package metadata
- the host is overloaded enough that package installation becomes unreliable

This repository provides one portable shell script that detects the Linux package manager and installs a practical troubleshooting baseline.

> Best practice: install the core toolbox during server provisioning. The download commands below are a fallback, not a substitute for incident readiness.

## Features

- Detects the Linux distribution through `/etc/os-release`
- Detects `apt-get`, `dnf`, `yum`, `zypper`, `apk`, or `pacman`
- Installs packages from the system's already configured repositories
- Does **not** run an OS upgrade
- Does **not** enable, start, stop, or restart services
- Skips packages that are unavailable instead of aborting the entire run
- Safe to run repeatedly
- Includes `--dry-run`
- Keeps heavier tracing tools behind `--advanced`
- Performs a final command availability check

## Supported Linux families

| Family | Package manager | Support |
| --- | --- | --- |
| Debian, Ubuntu, Linux Mint, Pop!_OS | `apt-get` | Primary |
| Fedora, RHEL, Rocky Linux, AlmaLinux, CentOS, Amazon Linux | `dnf` / `yum` | Supported |
| openSUSE, SLES | `zypper` | Supported |
| Alpine Linux | `apk` | Supported |
| Arch Linux, Manjaro | `pacman` | Best effort |

Package availability differs between distro versions and enabled repositories. Advanced tools are therefore best effort and unavailable packages are skipped.

## Quick start

Replace the values below with your GitHub username and repository name:

```bash
GITHUB_USER="<YOUR_GITHUB_USERNAME>"
REPO="<YOUR_REPOSITORY_NAME>"

curl -fL --proto '=https' --tlsv1.2 \
  "https://raw.githubusercontent.com/${GITHUB_USER}/${REPO}/main/linux-crisis-tools.sh" \
  -o /tmp/linux-crisis-tools.sh

chmod 700 /tmp/linux-crisis-tools.sh
sudo /tmp/linux-crisis-tools.sh
```

### wget fallback

If `curl` is not installed:

```bash
GITHUB_USER="<YOUR_GITHUB_USERNAME>"
REPO="<YOUR_REPOSITORY_NAME>"

wget -O /tmp/linux-crisis-tools.sh \
  "https://raw.githubusercontent.com/${GITHUB_USER}/${REPO}/main/linux-crisis-tools.sh"

chmod 700 /tmp/linux-crisis-tools.sh
sudo /tmp/linux-crisis-tools.sh
```

## Safer production usage

For production systems, pin the download to a release tag or immutable commit SHA instead of `main`.

```bash
GITHUB_USER="<YOUR_GITHUB_USERNAME>"
REPO="<YOUR_REPOSITORY_NAME>"
REF="v1.0.0"   # or an immutable Git commit SHA

BASE_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${REPO}/${REF}"

curl -fL --proto '=https' --tlsv1.2 \
  "${BASE_URL}/linux-crisis-tools.sh" \
  -o /tmp/linux-crisis-tools.sh

curl -fL --proto '=https' --tlsv1.2 \
  "${BASE_URL}/SHA256SUMS" \
  -o /tmp/SHA256SUMS

(
  cd /tmp
  sha256sum -c SHA256SUMS
)

chmod 700 /tmp/linux-crisis-tools.sh
sudo /tmp/linux-crisis-tools.sh
```

Reviewing the file before execution is also recommended:

```bash
less /tmp/linux-crisis-tools.sh
```

This project intentionally does not recommend `curl ... | sudo bash` as the default installation method.

## Usage

### Install the core toolbox

Recommended for most servers:

```bash
sudo ./linux-crisis-tools.sh
```

Equivalent:

```bash
sudo ./linux-crisis-tools.sh --core
```

### Preview without changing the system

```bash
./linux-crisis-tools.sh --dry-run
```

### List packages selected for the current OS

```bash
./linux-crisis-tools.sh --list
```

### Install advanced tracing tools

```bash
sudo ./linux-crisis-tools.sh --advanced
```

### Skip package metadata refresh

Useful when repository metadata is already current or network access is limited:

```bash
sudo ./linux-crisis-tools.sh --no-refresh
```

### Show version

```bash
./linux-crisis-tools.sh --version
```

## What gets installed

The exact package name varies by distribution.

### Core toolbox

| Area | Typical commands |
| --- | --- |
| Process | `ps`, `top`, `pgrep`, `pkill`, `fuser` |
| CPU and memory | `vmstat`, `mpstat`, `pidstat` |
| Disk and I/O | `iostat`, `sar`, `lsblk`, `findmnt` |
| Network | `ip`, `ss`, `ping`, `mtr`, `traceroute` |
| DNS | `dig` |
| Packet analysis | `tcpdump`, `ethtool` |
| Process debugging | `lsof`, `strace` |
| Connectivity | `curl`, `wget`, `nc`, `socat` |
| Data inspection | `jq`, `file` |
| TLS | `openssl` |
| File transfer | `rsync` |

### Advanced toolbox

`--advanced` attempts to add tools such as:

```text
ltrace
iotop
perf
bpftrace
BCC tools
blktrace
numactl
trace-cmd
iperf3
```

Availability depends on the distribution, kernel, architecture, and configured repositories.

## Examples during an incident

### High CPU

```bash
top
pidstat -u 1
mpstat -P ALL 1
```

### High memory usage

```bash
free -h
vmstat 1
ps aux --sort=-%mem | head
```

### Disk I/O latency

```bash
iostat -xz 1
pidstat -d 1
lsblk
```

### Listening ports and connections

```bash
ss -lntup
ss -s
```

### DNS problems

```bash
cat /etc/resolv.conf
dig example.com
```

### Packet investigation

```bash
sudo tcpdump -ni any
```

### Process syscall investigation

```bash
sudo strace -p <PID>
```

`strace`, packet capture, eBPF, and performance tracing can add overhead or expose sensitive data. Use them deliberately on production systems.

## Safety model

The installer:

1. Reads `/etc/os-release`.
2. Detects an existing supported package manager.
3. Refreshes package metadata unless `--no-refresh` is used.
4. Installs packages one at a time.
5. Skips packages that fail or are unavailable.
6. Does not change application configuration.
7. Does not perform a system upgrade.
8. Does not start or restart services.
9. Does not download or execute third-party install scripts.

The script still requires root privileges for package installation.

## Important limitation

This repository cannot solve the case where the affected server has already lost all outbound connectivity.

If DNS, routing, firewall rules, HTTPS connectivity, package repositories, or GitHub access are unavailable, neither `curl` nor `wget` can retrieve this script.

For critical systems, install the core tools when the server is built:

```text
golden image / cloud-init / Ansible / Terraform provisioner
                     |
                     v
           Linux Crisis Tools
                     |
                     v
          application deployment
```

Treat this repository as both a provisioning helper and an emergency fallback.

## Verify the repository copy

```bash
sha256sum -c SHA256SUMS
bash -n linux-crisis-tools.sh
```

For additional static analysis:

```bash
shellcheck linux-crisis-tools.sh
```

GitHub Actions runs syntax validation, checksum validation, and ShellCheck on pushes and pull requests.

## Repository structure

```text
.
├── .github/
│   └── workflows/
│       └── shellcheck.yml
├── LICENSE
├── README.md
├── SECURITY.md
├── SHA256SUMS
└── linux-crisis-tools.sh
```

## Updating the script

After changing `linux-crisis-tools.sh`, regenerate the checksum:

```bash
sha256sum linux-crisis-tools.sh > SHA256SUMS
```

Then verify it:

```bash
sha256sum -c SHA256SUMS
```

For stable production use, create a Git tag or GitHub Release:

```bash
git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
```

Users can then download from `v1.0.0` instead of the mutable `main` branch.

## License

MIT. See [LICENSE](LICENSE).
