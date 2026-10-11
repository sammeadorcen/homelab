# Architecture

## Goals

1. **Nothing at home is exposed.** The apartment network has no port forwarding
   and I don't trust it anyway.
2. **Survives a move.** The home box only makes outbound connections, so it can be
   plugged in anywhere with internet and comes back with the same mesh address.
   No static IPs, no DHCP reservations, no router config.
3. **Set and forget.** OS, Docker images and the mesh client all update
   themselves; reboots are scheduled around people playing.
4. **Configs match reality.** Everything in this repo is what actually runs.

## Hosts

| | cloud01 | onprem01 |
|---|---|---|
| Where | Linode, shared 2 vCPU / 4 GB | Home, 12th-gen Intel i7, 16 GB RAM, 500 GB disk |
| OS | Debian 13 | Debian 13 (headless) |
| Public IP | Yes, four ports | None |
| Role | Mesh control plane, public edge, monitoring | Game servers, media |
| Fallback access | Linode Lish console | Keyboard and monitor |

## Request paths

**Public (Vaultwarden):** internet → Linode Cloud Firewall → UFW → Traefik
(CrowdSec → hardening headers) → Vaultwarden.

**Admin service on cloud01 (e.g. Grafana):** my laptop → NetBird (WireGuard) →
`wt0` on cloud01 → Traefik (`mesh-only` → hardening) → Grafana. Off the mesh the
hostname still resolves, to a `100.64.0.0/10` address nothing outside can route to.

**Minecraft:** friend's PC (Google login → `All` group) → NetBird → onprem01's
mesh IP, port 25565 → Wings-managed container. The policy allows that port and
nothing else.

**Panel → Wings:** both on onprem01. The Panel container resolves
`wings.<domain>` to the mesh IP, its traffic leaves the Docker bridge to the
host, Traefik terminates TLS with the wildcard cert and forwards to Wings.
Wings calls back to the Panel through the bridge gateway via `extra_hosts`.

## DNS

Cloudflare, all records DNS-only (grey cloud):

- Public A/AAAA → cloud01's public IP: NetBird and Vaultwarden.
- Public A → **mesh IPs**: every admin service, the game panel and Minecraft.
  No split DNS, no local resolver, nothing to configure per device.

Mail records on the apex are separate and untouched.

## Updates

| What | How | When |
|---|---|---|
| Debian, Docker, NetBird client | unattended-upgrades | Daily |
| cloud01 reboot | unattended-upgrades | 04:30 if needed |
| onprem01 reboot | `maybe-reboot` timer | Tue 05:00 if needed and no players online |
| Containers (opt-in) | Watchtower | 04:00 nightly |
| Wings | By hand, with the Panel | When the Panel updates |

## Monitoring

Prometheus on cloud01 scrapes node-exporter and cAdvisor on both boxes (the home
ones over the mesh). Grafana for history, Uptime Kuma for up/down checks, Dozzle
for container logs, Homer as the start page.

## Roadmap

- Ethernet run for onprem01 (it's on a Wi-Fi extender today).
- Retire debrid streaming for local media: Proxmox on onprem01 plus a second
  Proxmox storage server (mergerfs + SnapRAID over XFS data disks, ZFS mirror for
  VMs), Jellyfin with Intel Quick Sync, an *arr stack, downloads behind a VPN
  container. All of it mesh-only.
