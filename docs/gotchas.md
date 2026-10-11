# Lessons learned

Each of these cost at least an hour. Most of them fail silently.

## Traefik

- **Host networking, not published ports.** Published ports NAT every request to
  the bridge gateway, so `ipAllowList` and CrowdSec see one internal IP for the
  whole internet.
- **`CLOUDFLARE_DNS_API_TOKEN`** is the exact env var name the ACME library reads.
- **Wildcard certificates.** Per-host certs are re-requested together on restart
  and trip Cloudflare's API rate limit (`429`), leaving you with no certs for an hour.
- **`traefik:v3.6`.** Older v3 releases can't negotiate with Docker Engine 29 and
  never see a container.
- **Middlewares from the file provider are `name@file`**, not `@docker`.
- **A placeholder like `100.x.x.x` left in an address field** is treated as a
  hostname and fails with `no such host`.

## Docker networking

- **A network you create by hand ignores `default-address-pools`.**
  `docker network create stack_default` took `172.18.0.0/16`, not the
  `172.20.0.0/16` in `daemon.json`. Every firewall rule written for `172.20`
  silently matched nothing. Always inspect the real subnet.
- **Containers reaching a host-networked Traefik need two UFW rules**: `ufw allow`
  (INPUT) and `ufw route allow` (FORWARD). With only one you get `curl: (28)`
  timeouts that look like a routing problem.
- **Docker bypasses UFW for published ports.** Bind exporters and game servers to
  the mesh IP explicitly; don't rely on the firewall to hide `0.0.0.0`.
- **Make Docker wait for `wt0`** on the home server, or mesh-IP binds fail after
  a reboot. Never do this on the box that runs the NetBird server in Docker: the
  boot deadlocks.
- **Bind-mounted files must exist first.** If the source is missing, Docker
  creates a directory there (Filebrowser's DB, Vaultwarden's log for CrowdSec).

## Pelican Panel and Wings

- **Image is `ghcr.io/pelican/panel`.** `pelican-dev/panel` returns `denied`.
- **`BEHIND_PROXY: "true"`** or the container refuses to start without a Let's
  Encrypt email. **`TRUSTED_PROXIES` as a CIDR** or the CSS loads over `http://`
  and the page has no styling. **`DB_CONNECTION` + `DB_DATABASE`** or the
  entrypoint loops on `nc: bad port ''`. The container runs as UID 82.
- **Paste the node config instead of running `wings configure`.** The token is
  single-use and failures are silent.
- **Wings in a container can't reach the Panel's mesh IP.** `extra_hosts` maps
  the Panel hostname to the bridge gateway, where Traefik is listening. Pointing
  `remote:` at the container name instead starts fine and then rejects every
  console websocket.
- **"does not match node token_id" was CORS.** The node heart and console are
  direct browser → Wings calls. `allowed_origins` fixes it, and
  `ignore_panel_config_updates: true` stops the Panel overwriting it on the next save.
- **Wings keeps a stale Docker socket after a Docker upgrade.** Every operation
  fails with `connection refused` until Wings is restarted.

## NetBird

- **`--management-url` is required on `netbird up`.** Without it the client joins
  NetBird's hosted cloud, reports success, and never appears in your dashboard.
- **The apt repo's origin is `Artifactory`**, not `Netbird`. With the wrong
  origin in unattended-upgrades, clients never update.
- **Watchtower and the NetBird server.** I let the control plane update nightly.
  The risk is a breaking release; the backup includes `config.yaml` and the data
  volume together so a rollback is possible.

## Hosts

- **Enable UFW only after a second way in exists.** On the home box `wt0` doesn't
  exist yet during the build, so a temporary LAN SSH rule comes first and is
  removed once mesh SSH works.
- **AlmaLinux 10 + Docker failed** on a missing iptables `addrtype` module. Debian
  13 avoided it, along with SELinux bind-mount labelling.
- **Debian cloud images log SSH to journald**, so fail2ban needs `backend = systemd`.
- **Real-Debrid blocks datacenter IPs.** Anything that streams through it has to
  run at home, not on the VPS.
