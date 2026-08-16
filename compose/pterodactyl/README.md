# Pterodactyl — game servers

Runs the game-server control panel at **panel.hamdy.app** and the Minecraft
server players reach at **cosmosworld.hamdy.app**.

## Why this is a separate stack

`make update` does `prod-down` then `prod`. If Pterodactyl lived in the main
`docker-compose.yml`, redeploying the portfolio would kick everyone off a live
Minecraft server. Game servers have their own lifecycle, so they get their own
stack and their own make targets:

```bash
make game        # start
make game-down   # stop (does NOT stop running game servers — Wings owns those)
make game-logs
make game-ps
```

## The pieces

| Piece | Where it runs | Notes |
|---|---|---|
| `panel` | container, this stack | Pterodactyl web UI. No host port; Caddy reaches it over `hamdy-platform_web`. |
| `database` / `cache` | containers, internal only | MariaDB + Redis. Never published. |
| `ddns` | container, this stack | Keeps the `cosmosworld.hamdy.app` A record on the current home IP. |
| **`wings`** | **systemd on the host** | Not in this stack. `systemctl status wings`. |

Wings drives the host Docker daemon to spawn game-server containers, so
containerising it buys nothing and breaks path mapping. It is installed as a
plain binary — see `DEPLOY.md`.

## Traffic split

```
players ──► cosmosworld.hamdy.app (grey cloud, A) ──► home IP :25565 ──► gateway NAT ──► server
you     ──► panel.hamdy.app ─┐
            node.hamdy.app ──┴─► Cloudflare ─► existing tunnel ─► Caddy ─┬─► panel:80
                                                                        └─► host :8081 (wings)
```

Only the game port is forwarded. Everything HTTP rides the tunnel that already
existed. The reasoning is in [`../../decisions/0002`](../../decisions/0002-port-forward-for-minecraft.md).

## Things that will bite you

**Port 8081, not 8080.** Pi-hole's admin UI owns 8080 on this host. Wings is on
8081, and there is a ufw rule allowing it from the Docker bridge ranges only.

**The panel node's "Daemon Port" must stay 443.** The panel connects to
`https://node.hamdy.app:443` through Cloudflare; Caddy forwards to Wings on
8081. Cloudflare only proxies a fixed set of ports and 8081 is not one of them.
Regenerating the node config from the panel **overwrites `api.port` back to the
panel's daemon port** — if you ever do that, set it back to 8081 in
`/etc/pterodactyl/config.yml` and restart Wings.

**Allocations use `0.0.0.0`, deliberately.** The AT&T gateway resolves NAT rules
through DHCP leases, and this server's `.10` is static, so it DNATs to the
Wi-Fi interface instead. Binding all interfaces sidesteps it. Full story in
ADR 0002.

**Subnets are pinned.** 172.17–172.21 were already taken when this was built;
this stack's internal network is 172.23.0.0/16 and Wings' `wings0` is
172.22.0.0/16. Neither can be left to Docker's auto-assignment.

**Never lose the `panel_var` volume.** It holds the generated `APP_KEY`. Without
it every encrypted value in the database — including the node's Wings token —
becomes unreadable and the node has to be recreated.

**Cloudflare caps uploads at 100 MB** on the free plan, and the node is
configured to match. Larger worlds/modpacks go over SFTP on the LAN
(port 2022, not forwarded), or by dropping files into
`/var/lib/pterodactyl/volumes/<server-uuid>/` directly.

## Current server

`hamdy-smp` — Paper 26.2 on `yolks:java_25` (Minecraft 26.2 requires Java 25),
8 GB heap, 20 GB disk, allocation `0.0.0.0:25565`.

`online-mode` is on, so a real Mojang account is required. The **whitelist is
off** by choice — anyone with a legitimate account can join. To change that,
in the panel console:

```
whitelist on
whitelist add <username>
```
