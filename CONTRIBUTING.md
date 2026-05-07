# Contributing

Contributions are welcome, especially test reports from different amd64 environments.

## Useful test matrix

Please include:

- hypervisor or hardware model;
- Debian version and architecture;
- installation mode used: `x11`, `wayland`, or `both`;
- selected profile: `minimal`, `standard`, or `full`;
- whether NetworkManager takeover was used;
- output of the diagnostic script.

Run diagnostics:

```bash
sudo ./scripts/rpd-amd64-diagnose.sh
```

## Coding style

- Keep the main script POSIX-friendly where practical, but Bash is allowed.
- Use explicit logging.
- Avoid destructive operations without backup.
- Prefer safe defaults.
- Do not disable APT signature verification.
- Do not use `trusted=yes` for repositories.
