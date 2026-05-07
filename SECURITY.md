# Security policy and considerations

## Supported scope

This project is an unofficial experimental post-install tool for Debian 13 Trixie amd64.

Security reports should focus on:

- unsafe shell behavior;
- APT repository or pinning mistakes;
- privilege escalation mistakes introduced by the scripts;
- unsafe handling of network configuration;
- dangerous cleanup or package removal behavior.

## APT repository trust

The script adds the Raspberry Pi Debian archive using a dedicated keyring:

```text
/usr/share/keyrings/raspberrypi-archive-keyring.gpg
```

The repository is pinned conservatively so Debian remains the primary source for the base system.

## SHA1 / APT Sequoia workaround

The script can create:

```text
/etc/crypto-policies/back-ends/apt-sequoia.config
```

This temporarily relaxes APT/Sequoia SHA1 policy for legacy third-party repository key compatibility.

This is not ideal. It is documented, opt-out capable, and reversible:

```bash
sudo rm -f /etc/crypto-policies/back-ends/apt-sequoia.config
sudo apt update
```

Use the shortest practical date with:

```bash
--legacy-sha1-until YYYY-MM-DD
```

## Dummy packages

The script may create local dummy packages for missing RPD network plugin dependencies. These packages contain only metadata and documentation, not binaries.

Inspect them with:

```bash
dpkg -s lpplug-netman
dpkg -s wfplug-netman
```

Remove them with:

```bash
sudo dpkg -r lpplug-netman wfplug-netman
```

## NetworkManager takeover

The option:

```bash
--network-manager-takeover yes
```

modifies network management for the primary interface. This can temporarily interrupt connectivity. Prefer running it from a local console or VM console.

The default `auto` mode skips this operation when an SSH session is detected.

## Reporting vulnerabilities

Open a private security advisory if the repository supports it, or contact the maintainer directly. Do not publish exploitable details before a fix is available.
