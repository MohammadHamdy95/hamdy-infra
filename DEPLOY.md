# Deploying hamdy.app

How to get the platform running on the server: get the code, create the
cloud resources once, update them later as needed, and start/stop the
services day to day.

The platform runs on **hamdyserver** (`ssh mo@192.168.1.10`), in
`/opt/stacks/hamdy-platform/`. That host also runs Pi-hole, which is
why its Docker daemon has explicit DNS configured in
`/etc/docker/daemon.json` — the host resolver is 127.0.0.1, which
BuildKit containers cannot reach, so `docker build` fails with
`UnknownHostException` without it.

Two different machines are involved and it's worth being clear about
which does what:

- **Your own machine** — runs `terraform apply`. Terraform only talks to
  the Cloudflare and AWS APIs over the internet; it has no reason to run
  on the server itself.
- **The server** — runs the six repos as one Docker Compose stack. It
  only needs the values Terraform produced, copied into its `.env`.

## Prerequisites

On the server: `docker` + the `docker compose` plugin, and `git` (or the
[`gh` CLI](https://cli.github.com/), already used throughout this
project — `gh auth login` once, then it can clone private repos without
juggling SSH keys).

On your own machine: `terraform` and either `gh` or an SSH key on
GitHub, to run the two `terraform apply`s.

## Get the code

All six repos are private, on GitHub as siblings of each other (that
sibling layout is required — `docker-compose.yml` builds each app from
`../../<repo>` relative to `hamdy-infra/compose/`). Run this once on the
server, in whatever parent directory you want the platform to live in:

```bash
sudo mkdir -p /opt/stacks/hamdy-platform && sudo chown -R $USER /opt/stacks/hamdy-platform && cd /opt/stacks/hamdy-platform
for repo in hamdy-app tiny-frontend tiny-backend paste-frontend paste-backend hamdy-infra; do
  gh repo clone MohammadHamdy95/$repo
done
```

(No `gh`? `git clone git@github.com:MohammadHamdy95/$repo.git` works the
same way, given an SSH key registered with GitHub.)

To update the code later (new commits to any app), `cd` into that repo
and `git pull` — see [Starting and stopping the
services](#starting-and-stopping-the-services) for picking the change up.

## One-time: create the cloud resources

Run from **your own machine**, not the server.

1. Copy `.env.example` (this directory) to `.env` and fill in
   `CLOUDFLARE_API_TOKEN` and the `TF_DEPLOYER_AWS_*` pair — see that
   file for exactly what each is and where it comes from.

2. Cloudflare stack — creates the tunnel and every subdomain's DNS record:

   ```bash
   cd terraform/cloudflare
   cp terraform.tfvars.example terraform.tfvars   # fill in account_id, zone_id
   export CLOUDFLARE_API_TOKEN=<value from .env>
   terraform init
   terraform apply
   ```

   Save the tunnel token for the server's `.env`:

   ```bash
   terraform output -raw tunnel_token
   ```

3. AWS stack — creates the `links` DynamoDB table and the shortener's
   narrow IAM user:

   ```bash
   cd ../aws
   export AWS_ACCESS_KEY_ID=<TF_DEPLOYER_AWS_ACCESS_KEY_ID from .env>
   export AWS_SECRET_ACCESS_KEY=<TF_DEPLOYER_AWS_SECRET_ACCESS_KEY from .env>
   terraform init
   terraform apply
   ```

   Save the app's runtime credentials for the server's `.env`:

   ```bash
   terraform output tiny_access_key_id
   terraform output -raw tiny_secret_access_key
   ```

4. On the **server**, in `hamdy-infra/compose/`:

   ```bash
   cp .env.example .env
   ```

   Fill in the three values from steps 2–3: `TUNNEL_TOKEN`,
   `TINY_AWS_ACCESS_KEY_ID`, `TINY_AWS_SECRET_ACCESS_KEY`.
   However you copy them over (scp, paste over SSH, a password manager),
   never commit this file — it's gitignored, and it should stay that way.

Both `terraform apply`s are safe to run again later — see the next
section — and both are idempotent: re-running with no config changes
does nothing.

## Updating the cloud resources

Whenever infra config changes (a new subdomain, a policy tweak, raising
the shortener's TTL default), the loop is the same for either stack:

```bash
cd terraform/<cloudflare|aws>
terraform plan     # review what would change
terraform apply    # apply it
```

A few concrete cases:

- **Adding a new app's subdomain** — add one entry to the `apps` map in
  `terraform/cloudflare/variables.tf`, then `terraform apply` in that
  directory. The new DNS record and tunnel route are created; nothing
  else needs to change (see `HLD.md` §6 for the full new-app checklist).
- **Rotating the shortener's AWS key** — if it ever leaks or you just
  want to rotate it on a schedule:
  ```bash
  cd terraform/aws
  terraform taint aws_iam_access_key.tiny_backend
  terraform apply
  ```
  Then update `TINY_AWS_ACCESS_KEY_ID`/`SECRET` in the server's
  `compose/.env` and restart the tiny-backend service (see below).
- **Changing the DynamoDB table or IAM policy** — edit
  `terraform/aws/main.tf`, `terraform plan` to sanity-check, `apply`.

Terraform state for both stacks is currently local (on whichever machine
ran `apply`) — back up `terraform/*/terraform.tfstate` somewhere safe
until a remote backend is set up (noted as pending in `HLD.md`).

## Starting and stopping the services

All of this runs **on the server**, from the `hamdy-infra` directory.

```bash
make prod        # build + start everything, detached
make prod-down    # stop everything
```

Equivalent plain-compose commands, if you'd rather not use `make`:

```bash
docker compose -f compose/docker-compose.yml up -d --build
docker compose -f compose/docker-compose.yml down
```

Day to day:

```bash
docker compose -f compose/docker-compose.yml ps          # what's running
docker compose -f compose/docker-compose.yml logs -f      # follow all logs
docker compose -f compose/docker-compose.yml logs -f paste-backend   # just one service
```

**Picking up new app code** — pull all six repos and restart in one step
(run from `hamdy-infra`, assumes `gh auth login` was already done):

```bash
make update   # git pull everywhere, stop, rebuild, start — only rebuilds what changed
```

**Picking up infra-only changes** (Caddyfile, compose file itself) — no
rebuild needed, just recreate the affected containers:

```bash
docker compose -f compose/docker-compose.yml up -d
```

**Restarting a single service** (e.g. after rotating a credential in
`.env`):

```bash
docker compose -f compose/docker-compose.yml up -d --force-recreate tiny-backend
```

## SSH access

Port 22 is forwarded, so the server is reachable from anywhere:

```bash
ssh mo@107.219.133.158
```

**Key authentication only — passwords are disabled.** Currently exactly one
machine has keys (the MacBook Pro, RSA + ed25519). Adding another machine
means appending its public key to `~mo/.ssh/authorized_keys`, which needs LAN
or console access:

```bash
# from the new machine, having run ssh-keygen -t ed25519:
ssh-copy-id -i ~/.ssh/id_ed25519.pub mo@192.168.1.10   # only works on the LAN
```

Config lives in `/etc/ssh/sshd_config.d/01-hardening.conf`. **The `01-` prefix
matters** — sshd takes the first occurrence of a keyword and `50-cloud-init.conf`
sets `PasswordAuthentication yes`, so a higher-numbered file is silently
ignored. After any change:

```bash
sudo sshd -t && sudo sshd -T | grep -i passwordauth && sudo systemctl reload ssh
```

Use `reload`, never `restart` — reload keeps your current session alive if the
config is broken, and a broken sshd on this box means walking to it.

fail2ban watches the journal (not `auth.log`, which Ubuntu 26.04 no longer
writes) and bans brute-forcers via ufw:

```bash
sudo fail2ban-client status sshd
```

Rationale, the full verified list of open ports, and how to revert:
[`decisions/0003`](decisions/0003-ssh-exposed-key-only.md).

## Game servers (Pterodactyl)

A second, independent stack. It is deliberately **not** part of `make update`,
because that stops and rebuilds everything and would drop players out of a
running game. Overview and gotchas: [`compose/pterodactyl/README.md`](compose/pterodactyl/README.md).

```bash
make game        # start the panel stack
make game-down   # stop it (running game servers are Wings', and keep running)
make game-logs
```

Secrets live in `compose/pterodactyl/.env` (its own file, not `compose/.env`) —
copy `compose/pterodactyl/.env.example` and fill it in.

### Wings

Wings is **not** a container. It runs as a systemd unit on the host because it
drives the host Docker daemon to create game-server containers.

```bash
sudo systemctl status wings
sudo journalctl -u wings -f
```

Config is `/etc/pterodactyl/config.yml` (mode 600 — it holds the node token).
Two values in it are hand-tuned for this host and are **not** what the panel
would generate:

- `api.port: 8081` — Pi-hole owns 8080 on this machine
- `docker.network.*` on `172.22.0.0/16` — Wings defaults to 172.18, which is
  already taken here

Upgrading Wings:

```bash
sudo systemctl stop wings
sudo curl -L -o /usr/local/bin/wings \
  "https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64"
sudo chmod 755 /usr/local/bin/wings
sudo systemctl start wings
```

Do **not** regenerate the node config from the panel to "fix" a problem — it
rewrites `api.port` to the panel's Daemon Port (443) and Wings will try to bind
443 on the host. If you do regenerate, re-apply the two values above.

Upgrading the panel: bump the pinned tag in `compose/pterodactyl/compose.yaml`
and `make game`. The image runs migrations on boot.

### The one forwarded port

TCP 25565 → 192.168.1.10 on the AT&T gateway (Firewall → NAT/Gaming), plus the
grey-cloud `cosmosworld.hamdy.app` A record. Why this breaks the tunnel-only rule, what
is and isn't exposed, and the gateway quirk that makes allocations use
`0.0.0.0`: [`decisions/0002`](decisions/0002-port-forward-for-minecraft.md).

Changing the gateway needs its **Device Access Code**, printed on the unit.

Checking it from outside (never trust a LAN test — NAT hairpin lies):

```bash
curl -s https://api.mcstatus.io/v2/status/java/cosmosworld.hamdy.app
```
