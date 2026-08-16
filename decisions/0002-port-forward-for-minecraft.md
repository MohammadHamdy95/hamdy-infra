# ADR 0002: One forwarded port for Minecraft, everything else stays tunnelled

**Status:** accepted · **Date:** 2026-08-16 · **Amends:** [0001](0001-self-hosted-with-cloudflare-tunnel.md)

## Decision

Run game servers on the home server via Pterodactyl, and expose **exactly one
inbound port** — TCP 25565 — through a NAT rule on the AT&T gateway.
`mc.hamdy.app` is an **unproxied (grey-cloud) A record** pointing at the house's
public IP.

Everything else about the setup keeps ADR 0001's shape: the Pterodactyl panel
(`panel.hamdy.app`) and the Wings daemon API (`node.hamdy.app`) are ordinary
proxied CNAMEs riding the **existing** Cloudflare Tunnel, terminating at Caddy
like every other app. No new HTTP exposure, no second tunnel.

## Why the exception is unavoidable

ADR 0001 says "no port forwarding, home IP never exposed", and `HLD.md` §7 said
to keep the orange cloud on for every record. Minecraft cannot satisfy either:

- **The protocol is raw TCP**, not HTTP. A Cloudflare Tunnel carries HTTP(S).
  Proxying arbitrary TCP is what Spectrum does, and Spectrum is Enterprise-only.
- **Therefore the record must be grey-cloud.** A proxied record would hand
  players Cloudflare's anycast IPs, which will not speak the Minecraft protocol,
  and the connection simply fails.

There is no configuration that gets a vanilla Minecraft client onto a
tunnel-only host. The options were: expose one port, put the server somewhere
else (a VPS, defeating the point), or require every player to run a VPN client
(defeating "give your friends an address"). Exposing one port won.

## What is actually exposed

| | |
|---|---|
| Forwarded | **TCP 25565 only**, to 192.168.1.10, via one NAT/Gaming rule |
| Not forwarded | SFTP (2022), Wings API (8081), the panel, SSH, everything else |
| In public DNS | `mc.hamdy.app` → the house IP. Every other record still points at the tunnel. |
| Gateway | IP Passthrough **off**, NAT Default Server **off** — no accidental DMZ |

## Mitigations

- `online-mode=true` — a genuine Mojang/Microsoft account is required to join,
  so this is not an anonymous open door. `enforce-secure-profile=true` too.
- `enable-rcon=false`, `enable-query=false`, `enable-command-block=false` —
  no remote console, no amplification-friendly query port.
- Game servers are unprivileged containers Wings spawns on its own `wings0`
  bridge (172.22.0.0/16), isolated from the platform's `web` and `internal`
  networks. A compromised game server cannot see Cassandra or the app backends.
- Wings' own API is bound to the host but firewalled by ufw to the Docker
  bridge ranges only — it is reachable through Caddy and nothing else.
- The whitelist is currently **off** by the owner's choice, so `online-mode` is
  the only thing gating who joins. Turning it on is one console command
  (`/whitelist on`) if that stops being the right trade.

## Consequences

- The home IP is discoverable via `mc.hamdy.app`. Accepted: it is one port, and
  the address is meant to be handed to players anyway.
- The IP is dynamic. A `cloudflare-ddns` container in the Pterodactyl stack
  rewrites the record within ~5 minutes of a change; the Terraform resource
  carries `ignore_changes = [content]` so the two do not fight.
- `HLD.md` §7 has been amended to point here rather than assert something that
  is no longer true.

## The gateway quirk this cost an hour

The BGW320-505 maps a NAT rule to a **device**, and resolves that device to an
IP via its **DHCP lease**. This server's `eno1` holds `192.168.1.10`
*statically*, and DHCP for the LAN is served by Pi-hole, not the gateway — so
the gateway had no lease for `.10` and silently DNAT'd to `192.168.1.153`, the
Wi-Fi interface's leased address, even though its own table displayed
`192.168.1.10`.

Packets arrived at the host addressed to `.153` and were dropped, because Docker
had published the game port on `192.168.1.10` only.

**Fix:** Pterodactyl allocations use `0.0.0.0`, so Wings publishes the game port
on every interface and the rule works regardless of which address the gateway
picks. If a future game server mysteriously refuses external connections, check
this first:

```bash
sudo tcpdump -ni eno1 'tcp port 25565 and not src net 192.168.1.0/24'
```

If the destination address is not the one you forwarded to, this is why. The
deeper cleanup — dropping the redundant Wi-Fi link on a server that has wired
gigabit, which also removes a second default route — is deferred, not done.
