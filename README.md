# hamdy-infra

Infrastructure for the `hamdy.app` platform: the Docker Compose stack that runs on the local server, plus Terraform for everything outside it (Cloudflare DNS/tunnel, AWS DynamoDB for the shortener).

See the workspace-level `HLD.md` for the full design.

## Layout

```
compose/
├── docker-compose.yml   # the whole platform: Caddy, cloudflared, apps, Cassandra
├── Caddyfile            # hostname → container routing
└── cloudflared/         # tunnel config
terraform/
├── cloudflare/          # DNS records, tunnel, proxy/TLS rules for all subdomains
└── aws/                 # DynamoDB links table + IAM for the shortener backend
backup/                  # nightly Cassandra snapshot scripts
decisions/               # ADRs — one short md per big choice
```

## Secrets

Nothing sensitive is ever committed. `.env.example` (this directory) is the
master reference listing every secret the platform needs and where it's
consumed — copy it to `.env` and fill in for your own records, then copy
the relevant values into:

- your shell, ad-hoc, before `terraform apply` (Cloudflare token, AWS
  deployer credentials)
- `compose/.env` (gitignored; see `compose/.env.example`) — the tunnel
  token and the shortener's app-runtime AWS credentials

**The two AWS credential pairs are different identities** — your own
deployer credentials (used to run `terraform apply`, needs DynamoDB/IAM
permissions) vs. the narrow IAM user `terraform/aws` creates for the
shortener backend (links table only, output by that stack). Keep them
in separate env vars; see `.env.example` for the full explanation.

## Local testing (no Cloudflare, no AWS needed)

The dev stack runs the entire platform on your machine. It expects the app
repos checked out as **siblings** of this repo (the workspace layout), builds
them from source, and swaps cloud pieces for local stand-ins (DynamoDB Local,
Cassandra in a container).

```
make dev        # build + start everything
make dev-logs   # follow logs
make dev-down   # stop
```

Then open (browsers resolve `*.localhost` to 127.0.0.1 automatically):

| URL | App |
|---|---|
| http://hamdy.localhost | portfolio |
| http://tiny.localhost | shortener UI (`/api/*` → backend, other paths → redirect) |
| http://paste.localhost | paste UI (`/v1/*` → backend, other paths → UI) |

Same Caddy routing shape as prod (`Caddyfile.dev` mirrors `Caddyfile`), so if
it works locally, the prod wiring is the same. For CLI testing use
`curl -H "Host: tiny.localhost" http://localhost/...` (curl doesn't resolve
`*.localhost` subdomains).

## Deploying to the server

See [`DEPLOY.md`](DEPLOY.md): cloning the repos onto the server, the
one-time `terraform apply` that creates the cloud resources, updating
those resources later, and starting/stopping the Compose stack.
