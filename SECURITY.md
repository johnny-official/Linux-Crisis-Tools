# Security Policy

## Running this project safely

`linux-crisis-tools.sh` installs operating-system packages with root privileges. Review changes before running new versions on production systems.

Recommended workflow:

```bash
curl -fL --proto '=https' --tlsv1.2 "<RAW_URL>" -o /tmp/linux-crisis-tools.sh
less /tmp/linux-crisis-tools.sh
chmod 700 /tmp/linux-crisis-tools.sh
sudo /tmp/linux-crisis-tools.sh --dry-run
sudo /tmp/linux-crisis-tools.sh
```

For production systems:

- Prefer a release tag or immutable Git commit SHA over `main`.
- Verify `SHA256SUMS`.
- Do not run a downloaded script through `curl | bash`.
- Test changes on a disposable VM or container first.
- Review advanced tracing tools before using them on production workloads.

## Scope

The script is designed to:

- install packages from repositories already configured by the operating system
- avoid operating-system upgrades
- avoid service restarts
- avoid remote install scripts
- tolerate unavailable optional packages

It does not guarantee that every package exists on every release of every supported distribution.

## Reporting a vulnerability

If you find a security issue, avoid publishing exploit details in a public issue before the problem can be reviewed.

Use GitHub's private vulnerability reporting feature if it is enabled for this repository. Otherwise, open a minimal issue asking the maintainer for a private reporting channel.
