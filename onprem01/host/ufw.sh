#!/usr/bin/env bash
# Final UFW state on onprem01. Nothing is allowed from the LAN.
set -euo pipefail

ufw default deny incoming
ufw default allow outgoing

ufw allow in on wt0 comment 'NetBird mesh'

# Containers reaching Traefik on the host. Needs BOTH rules: INPUT and FORWARD.
# With only the first, Panel -> Wings times out (curl 28).
BRIDGE=172.18.0.0/16   # docker network inspect stack_default ...
ufw allow       from "$BRIDGE" to any port 443 proto tcp comment 'containers to Traefik'
ufw route allow from "$BRIDGE" to any port 443 proto tcp comment 'containers to Traefik (fwd)'

# Bootstrap note: when building, add a TEMPORARY LAN SSH rule BEFORE enabling
# UFW (wt0 doesn't exist yet), and delete it once SSH over the mesh works.
ufw --force enable
ufw status verbose
