#!/usr/bin/env bash
# Nightly restic backup: Pelican DB, Wings config, every game server volume.
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

if [ -f "$STACK/data/pelican/database/database.sqlite" ]; then
    sqlite3 "file:$STACK/data/pelican/database/database.sqlite?mode=ro" \
            ".backup '$DUMPS/pelican.sqlite'"
fi

# Wings config holds the node token. Without it, recovery means recreating
# the node, which orphans every server on it. (sudoers allows exactly this cat.)
sudo cat /etc/pelican/config.yml > "$DUMPS/wings-config.yml"
chmod 600 "$DUMPS/wings-config.yml"

# --limit-upload keeps this from saturating home upload overnight.
restic backup \
    --tag auto \
    --limit-upload 2000 \
    --exclude "$STACK/data/pelican/database/database.sqlite*" \
    --exclude "$STACK/data/traefik" \
    "$STACK" \
    /var/lib/pelican/volumes

restic forget --tag auto --prune \
    --keep-daily 14 --keep-weekly 8 --keep-monthly 12

[ "$(date +%u)" = "7" ] && restic check --read-data-subset=5%

[ -n "${HC_URL:-}" ] && curl -fsS -m 10 "$HC_URL" >/dev/null || true
echo "Backup completed $(date -Is)"
