# homelab

Two boxes, one private mesh. A small Linode VPS is the only thing on the public
internet; a home server behind a managed apartment network (no port
forwarding) joins it over a self-hosted NetBird WireGuard mesh. Everything
except a password manager and the mesh's own control plane is reachable only
from inside the mesh.

Write-up: **https://meador.dev/docs** · Security model: [`docs/security.md`](docs/security.md)

```
                       Internet
                           │  80 · 443 · 3478/udp
               ┌───────────┴───────────┐
               │ cloud01  (Linode VPS) │
               │  Traefik · CrowdSec   │
               │  NetBird server  ◀────┼── every peer dials out to here
               │  Vaultwarden (public) │
               │  Grafana · Prometheus │
               │  Uptime Kuma · Dozzle │  mesh-only
               │  Homepage · Files     │
               └───────────┬───────────┘
                           │  WireGuard mesh (NetBird)
          ┌────────────────┼─────────────────┐
          ▼                ▼                 ▼
     my devices       friends' PCs      onprem01 (home)
     (admins)         (Minecraft only)  Pelican + Wings
                                        Minecraft (Fabric)
                                        Stremio · exporters
                                        no inbound ports at all
```

## Layout

| Path | What |
|---|---|
| `cloud01/stack/` | Compose stack for the VPS: Traefik, Vaultwarden, CrowdSec, monitoring, dashboard, Watchtower |
| `cloud01/netbird/` | How the NetBird control plane is installed and wired into Traefik |
| `cloud01/host/` | UFW, SSH, fail2ban, sysctl, unattended-upgrades, Docker daemon, backup timer |
| `onprem01/stack/` | Compose stack for the home server: Traefik, Pelican Panel, Wings, exporters |
| `onprem01/wings/` | Wings config template (the real one holds the node token) |
| `onprem01/host/` | UFW, Docker-waits-for-mesh drop-in, conditional reboot timer |
| `onprem01/minecraft/` | `server.properties` and the mod list |
| `docs/` | Architecture, access policies, monitoring, security model, lessons learned |
| `site/` | The static site at meador.dev (plain HTML, deployed on Cloudflare Workers) |

## Stack

Debian 13 · Docker Compose · Traefik v3.6 (Cloudflare DNS-01 wildcard certs) ·
NetBird (self-hosted, embedded IdP + Google SSO) · CrowdSec · fail2ban · UFW ·
Vaultwarden · Prometheus · Grafana · node-exporter · cAdvisor · Uptime Kuma ·
Dozzle · Homepage · Filebrowser · Pelican Panel + Wings · Fabric Minecraft ·
Watchtower · unattended-upgrades · restic

## Using it

Nothing here runs as-is. Every file uses `example.com` and placeholder values:

1. Copy each `*.example` file to its real name and fill it in. Real names are in `.gitignore`.
2. Replace `example.com` in the two `traefik.yml` files (Traefik's static config can't read env vars).
3. `docker network create stack_default` on each box, then check its real subnet:
   `docker network inspect stack_default --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}'`.
   Put that subnet in the UFW scripts, `middlewares.yml` and `.env`.
4. `docker compose up -d`.

Read [`docs/gotchas.md`](docs/gotchas.md) first. Most of it cost an evening.

## No secrets in this repo

API tokens, OAuth secrets, the CrowdSec bouncer key, the Wings node token,
NetBird's `config.yaml`, backup credentials, and real IP addresses are all kept
out. They live in gitignored files with `chmod 600` on the hosts. If you spot
something that looks like a real credential, please open an issue.

## License

MIT
