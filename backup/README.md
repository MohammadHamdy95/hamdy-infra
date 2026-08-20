# Backups

## OpenShare PostgreSQL

`apidocs-postgres.sh` creates a compressed PostgreSQL custom-format dump and keeps 14 days by default:

```bash
./backup/apidocs-postgres.sh
```

Production should run it nightly from root's crontab:

```cron
20 3 * * * /opt/stacks/hamdy-platform/hamdy-infra/backup/apidocs-postgres.sh >> /var/log/apidocs-backup.log 2>&1
```

Backups default to `/srv/backups/hamdy-platform/apidocs`, which is on the server's second NVMe. Override with `APIDOCS_BACKUP_DIR` and `APIDOCS_BACKUP_RETENTION_DAYS` when needed.

Restore into an empty database:

```bash
docker compose -f compose/docker-compose.yml exec -T apidocs-postgres \
  pg_restore -U apidocs -d apidocs --clean --if-exists < /path/to/apidocs.dump
```

Test restores periodically; a dump that has never been restored is not yet a verified backup.

## Other platform data

- Cassandra: take `nodetool snapshot` backups to the second disk.
- DynamoDB: AWS durability and point-in-time recovery cover Tiny's links.
