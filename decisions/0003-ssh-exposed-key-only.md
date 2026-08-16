# ADR 0003: SSH exposed on port 22, key-only

**Status:** accepted · **Date:** 2026-08-16 · **Amends:** [0001](0001-self-hosted-with-cloudflare-tunnel.md), [0002](0002-port-forward-for-minecraft.md)

## Decision

Forward TCP 22 to hamdyserver so the box is reachable by SSH from anywhere,
and make that safe by removing password authentication entirely rather than
by hiding the port.

## Why not the alternatives

Tailscale and Cloudflare Zero Trust SSH were both on the table and both avoid
opening a port at all. They were declined in favour of plain SSH: no client
software to install on every machine, and `ssh mo@<ip>` works from anything
with an SSH client, including a phone or a borrowed laptop.

A non-standard external port (2222 → 22) was also offered and declined. It
would cut log noise but is obscurity, not security, and the hardening below is
what actually matters.

## Hardening applied

`/etc/ssh/sshd_config.d/01-hardening.conf`:

| Setting | Value | Why |
|---|---|---|
| `PasswordAuthentication` | `no` | The whole basis for this being safe. No password = nothing to brute-force. |
| `PermitRootLogin` | `no` | `mo` has passwordless sudo; root over SSH buys nothing. |
| `AllowUsers` | `mo` | Only account that may log in. |
| `MaxAuthTries` | `3` | Drop early. |
| `LoginGraceTime` | `20` | Unauthenticated connections do not linger. |
| `MaxStartups` | `10:30:60` | Caps concurrent unauthenticated connections. |
| `X11Forwarding` / `AllowAgentForwarding` / `PermitTunnel` | `no` | Unused surface. |

**The filename prefix is load-bearing.** `/etc/ssh/sshd_config` has its
`Include sshd_config.d/*.conf` at line 24, and sshd honours the **first**
occurrence of a keyword, not the last. `50-cloud-init.conf` ships
`PasswordAuthentication yes`. A file named `99-*` would have been silently
ignored and passwords would have stayed on. `01-*` sorts first and wins.
`50-cloud-init.conf` was also set to `no`, but cloud-init may rewrite it on
boot — `01-hardening.conf` is the file actually guaranteeing this.

Never trust the file; check the effective config:

```bash
sudo sshd -t                                          # syntax
sudo sshd -T | grep -iE 'passwordauth|permitroot'     # what sshd will do
sudo systemctl reload ssh                             # reload, not restart
```

`reload` keeps existing sessions alive if the new config is broken. `restart`
does not. Given the machine is only otherwise reachable by walking to it, use
`reload`.

**fail2ban** (`/etc/fail2ban/jail.local`) bans on 5 failures in 10 minutes,
escalating ×2 per repeat offence up to a week, `banaction = ufw`. Backend is
`systemd` — Ubuntu 26.04 has no `/var/log/auth.log`, and the default file
backend would match nothing and appear to work. LAN and Docker ranges are in
`ignoreip`.

## Keys

Only **one machine** has access: the MacBook Pro, with two keys —
the original 4096-bit RSA and a new ed25519 (`mohamdy@macbook-pro-202608`).
No other machine ever had a key on either server; the other PCs had been
using passwords, which is precisely what this ADR removes. Adding a machine
means appending its public key to `~mo/.ssh/authorized_keys`, which now
requires LAN or console access to do.

Neither key has a passphrase, matching the pre-existing setup. Adding one
(`ssh-keygen -p -f ~/.ssh/id_ed25519`) is a real improvement for a key that
is now the only route into an internet-facing host.

**Recovery if every key is lost:** physical console. The machine is at home,
so this is acceptable. There is deliberately no password fallback.

## Full inbound exposure after this change

Verified from off-network, not from the LAN — a LAN test proves nothing here
because it never leaves the gateway:

| Port | What | Owner |
|---|---|---|
| 22 | SSH, key-only | this ADR |
| 80 / 443 | `bes-caddy` — `bes.ninja` resolves straight to the home IP, unproxied, and the BES stack has no `cloudflared` | BES migration |
| 25565 | Minecraft | [ADR 0002](0002-port-forward-for-minecraft.md) |

Confirmed closed: 25 (SMTP), 2022 (Wings SFTP), 3306, 5432, 8080 (Pi-hole),
8081 (Wings API), 25566–25570 (spare game allocations).

Note that ADR 0002's "exactly one forwarded port" is no longer literally true
— 80/443 arrived with the BES migration and 22 arrives here. The principle it
was defending still holds: nothing is forwarded that could have gone through
the tunnel instead.

To re-check exposure from outside at any time, from the legacy box:

```bash
ssh modev@76.91.194.141 'for p in 22 80 443 2022 3306 8080 8081 25565; do
  timeout 4 bash -c "exec 3<>/dev/tcp/107.219.133.158/$p" 2>/dev/null \
    && echo "OPEN $p" || echo "closed $p"; done'
```

## Reverting

```bash
# 1. Gateway: Firewall → NAT/Gaming → delete "SSH-hamdyserver"
#    (needs the Device Access Code on the unit)
# 2. Host:
sudo ufw delete allow 22/tcp
# 3. Optionally restore password auth for LAN use:
sudo rm /etc/ssh/sshd_config.d/01-hardening.conf
sudo sshd -t && sudo systemctl reload ssh
```
