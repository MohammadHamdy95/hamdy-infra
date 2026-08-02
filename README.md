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

Nothing sensitive is ever committed. Required environment:

- `CLOUDFLARE_API_TOKEN` — for `terraform/cloudflare`
- AWS credentials (`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) — for `terraform/aws`
- App runtime secrets go in `compose/.env` (gitignored; see `.env.example`)

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
| http://s.localhost | shortener UI (`/api/*` → backend, other paths → redirect) |
| http://paste.localhost | paste UI |
| http://api.paste.localhost | paste API |

Same Caddy routing shape as prod (`Caddyfile.dev` mirrors `Caddyfile`), so if
it works locally, the prod wiring is the same. For CLI testing use
`curl -H "Host: s.localhost" http://localhost/...` (curl doesn't resolve
`*.localhost` subdomains).

## Prod bring-up (on the server)

```
cd compose
cp .env.example .env   # fill in TUNNEL_TOKEN etc.
docker compose up -d
```
