# Monitoring and dashboard

Everything runs on cloud01 except the exporters, the Dozzle agent and a
read-only Docker socket proxy on onprem01. Nothing here is public.

| Piece | Where | Job | Alerts |
|---|---|---|---|
| Homepage | cloud01, `dash.<cloud domain>` | Start page: links, container status for both boxes, per-server CPU/RAM/disk from Prometheus, Uptime Kuma, CrowdSec, Traefik, Minecraft widgets | — |
| Prometheus | cloud01 | Scrapes node-exporter + cAdvisor (both boxes), Traefik (`:8082`), CrowdSec (`:6060`) every 30 s; 90-day retention | — |
| Grafana | cloud01 | Dashboards + alert rules | Email (Workspace SMTP) |
| Uptime Kuma | cloud01 | HTTP / GameDig / TCP checks every 60 s; status page `homelab` feeds Homepage | Email (Workspace SMTP) |
| Dozzle + agent | UI cloud01, agent onprem01 `:7007` (mesh IP) | Live logs for both boxes | — |
| healthchecks.io | outside | `heartbeat` timer every 5 min, only if Vaultwarden and NetBird answer | Email |

## Grafana

Data source is provisioned from `cloud01/stack/grafana/provisioning/`.
Dashboards imported from grafana.com: Node Exporter Full (1860), Cadvisor
exporter (14282), Traefik Official Standalone (17346).

| Alert | Query | Fires when | For |
|---|---|---|---|
| Disk almost full | `100 - 100 * node_filesystem_avail_bytes{mountpoint="/",fstype!="tmpfs"} / node_filesystem_size_bytes{mountpoint="/",fstype!="tmpfs"}` | > 85 | 10m |
| Memory high | `100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)` | > 90 | 10m |
| CPU pegged | `100 - 100 * avg by (host) (rate(node_cpu_seconds_total{mode="idle"}[5m]))` | > 90 | 15m |
| Target down | `up` | < 1 | 5m |

## Uptime Kuma monitors

Vaultwarden (`/alive`), NetBird, Grafana (`/api/health`), Traefik dashboard,
Dozzle, Homepage, Pelican Panel, Wings (`/api/system`, 401 accepted), AIOStreams (`/api/v1/status`),
AIOMetadata (`/health`),
Minecraft (GameDig), onprem01 (TCP 9100).

## Plumbing that makes it work

- cloud01 `mesh-only` includes the Docker bridge subnet, and UFW allows bridge →
  443 (in + route) and bridge → 8082.
- Traefik's `websecure` entry point is `asDefault: true`, so only routers that
  ask for `metrics` land on `:8082` (none do; it serves `/metrics` only).
- onprem01 exporters, Dozzle agent and socket proxy bind to its mesh IP; Docker
  waits for `wt0` there, so the binds survive reboots.
