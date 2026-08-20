#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
infra_dir="$(cd "$script_dir/.." && pwd)"
backup_dir="${APIDOCS_BACKUP_DIR:-/srv/backups/hamdy-platform/apidocs}"
retention_days="${APIDOCS_BACKUP_RETENTION_DAYS:-14}"

if [[ "$backup_dir" != /* || "$backup_dir" == "/" ]]; then
  echo "APIDOCS_BACKUP_DIR must be a specific absolute path" >&2
  exit 1
fi

mkdir -p "$backup_dir"
destination="$backup_dir/apidocs-$(date -u +%Y%m%dT%H%M%SZ).dump"

docker compose -f "$infra_dir/compose/docker-compose.yml" \
  exec -T apidocs-postgres pg_dump -U apidocs -d apidocs -Fc > "$destination"

test -s "$destination"
find "$backup_dir" -type f -name 'apidocs-*.dump' -mtime "+$retention_days" -delete
echo "Wrote $destination"

