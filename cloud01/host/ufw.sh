#!/usr/bin/env bash
# Final UFW state on cloud01. Run once, as root.
# The Linode Cloud Firewall in front mirrors the public rules (default drop).
set -euo pipefail

ufw default deny incoming
ufw default allow outgoing

ufw allow 80/tcp   comment 'ACME redirect'
ufw allow 443/tcp  comment 'HTTPS'
ufw allow 443/udp  comment 'HTTP/3'
ufw allow 3478/udp comment 'NetBird STUN'

# Mesh traffic. NetBird policies decide what each peer may actually reach.
ufw allow in on wt0 comment 'NetBird mesh'

# Containers reaching Traefik on the host (e.g. NetBird dashboard -> API).
# Check the real subnet first; a hand-made network ignores daemon.json pools:
#   docker network inspect stack_default --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'
BRIDGE=172.18.0.0/16
ufw allow from "$BRIDGE" to any port 443 proto tcp comment 'containers to Traefik'

# No port 22 rule: SSH is mesh-only. Console (Lish) is the fallback.
ufw --force enable
ufw status verbose
