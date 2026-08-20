# Backups

Nightly cron: `nodetool snapshot` on the Cassandra container → tarball to a
second disk (or cloud storage). Scripts land here when Cassandra comes online.

Shortener data needs no backup here — DynamoDB is durable on its own (PITR
enabled via Terraform).
