# Deploying hamdy.app

How to get the platform running on the server: get the code, create the
cloud resources once, update them later as needed, and start/stop the
services day to day.

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
mkdir -p hamdy-platform && cd hamdy-platform
for repo in hamdy-app shortener-frontend shortener-backend paste-frontend paste-backend hamdy-infra; do
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
   terraform output shortener_access_key_id
   terraform output -raw shortener_secret_access_key
   ```

4. On the **server**, in `hamdy-infra/compose/`:

   ```bash
   cp .env.example .env
   ```

   Fill in the three values from steps 2–3: `TUNNEL_TOKEN`,
   `SHORTENER_AWS_ACCESS_KEY_ID`, `SHORTENER_AWS_SECRET_ACCESS_KEY`.
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
  terraform taint aws_iam_access_key.shortener_backend
  terraform apply
  ```
  Then update `SHORTENER_AWS_ACCESS_KEY_ID`/`SECRET` in the server's
  `compose/.env` and restart the shortener-backend service (see below).
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

**Picking up new app code** — pull all six repos (run from `hamdy-infra`,
assumes `gh auth login` was already done):

```bash
for repo in ../hamdy-app ../shortener-frontend ../shortener-backend ../paste-frontend ../paste-backend ../hamdy-infra; do
  (cd "$repo" && git pull)
done
```

Then rebuild:

```bash
make prod   # re-runs `up -d --build` — only rebuilds what changed
```

**Picking up infra-only changes** (Caddyfile, compose file itself) — no
rebuild needed, just recreate the affected containers:

```bash
docker compose -f compose/docker-compose.yml up -d
```

**Restarting a single service** (e.g. after rotating a credential in
`.env`):

```bash
docker compose -f compose/docker-compose.yml up -d --force-recreate shortener-backend
```
