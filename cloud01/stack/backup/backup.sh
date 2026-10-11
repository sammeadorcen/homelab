#!/usr/bin/env bash
# Nightly restic backup of /srv/stack + NetBird state to S3-compatible storage.
set -Eeuo pipefail

STACK=/srv/stack
DUMPS="$STACK/backup/dumps"
source "$STACK/backup/backup.env"

fail() {
    echo "BACKUP FAILED at line $1" >&2
    [ -n "${HC_URL:-}" ] && curl -fsS -m 10 "${HC_URL}/fail" >/dev/null || true
    exit 1
}
trap 'fail $LINENO' ERR

USED=$(df --output=pcent / | tail -1 | tr -dc '0-9')
[ "$USED" -ge 90 ] && { echo "Disk at ${USED}% — aborting" >&2; exit 1; }

mkdir -p "$DUMPS"; chmod 700 "$DUMPS"

# Vaultwarden: consistent SQLite copy while running.
sqlite3 "file:$STACK/data/vaultwarden/db.sqlite3?mode=ro" \
        ".backup '$DUMPS/vaultwarden.sqlite3'"

# NetBird: config dir AND data volume together. config.yaml holds the key
# that encrypts the database — one without the other restores to nothing.
tar czf "$DUMPS/netbird-config.tgz" -C /srv netbird
NBVOL=$(docker volume ls -q | grep -E 'netbird.*data' | head -1)
docker run --rm -v "$NBVOL":/data -v "$DUMPS":/backup alpine \
    tar czf /backup/netbird-data.tgz -C /data .

restic backup \
    --tag auto \
    --exclude "$STACK/data/vaultwarden/db.sqlite3*" \
    --exclude "$STACK/data/vaultwarden/icon_cache" \
    --exclude "$STACK/data/vaultwarden/vaultwarden.log" \
    --exclude "$STACK/data/traefik" \
    --exclude "$STACK/data/traefik-logs" \
    --exclude "$STACK/data/prometheus" \
    --exclude "$STACK/data/crowdsec/data" \
    "$STACK"

restic forget --tag auto --prune \
    --keep-daily 14 --keep-weekly 8 --keep-monthly 12

[ "$(date +%u)" = "7" ] && restic check --read-data-subset=5%

[ -n "${HC_URL:-}" ] && curl -fsS -m 10 "$HC_URL" >/dev/null || true
echo "Backup completed $(date -Is)"
