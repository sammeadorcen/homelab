# Security model

## What I'm protecting against

- **Internet background noise:** scanners, credential stuffing, CVE probes.
  Constant, automated, aimed at whatever answers.
- **The home network.** It's a managed apartment network I don't control. I treat
  it as hostile, the same as the internet.
- **A compromised friend account.** Someone on the mesh should get Minecraft and
  nothing else.
- **My own mistakes.** Forgotten open ports, unpatched packages, a config that
  silently stops matching.

Out of scope: a targeted attacker with resources, physical access to the home
box, and compromise of Linode, Cloudflare or Google themselves.

## Attack surface

The whole public surface is one VPS and four ports:

| Port | Service | Why it must be public |
|---|---|---|
| 80/tcp | Traefik → 301 to HTTPS | Redirect only, serves nothing |
| 443/tcp+udp | Traefik | NetBird dashboard/API/relay, Vaultwarden |
| 3478/udp | NetBird STUN | Peers discover their NAT mapping |

Two hostnames answer on 443 from the internet: the NetBird control plane (it has
to, since it's how devices join) and Vaultwarden (password apps need it from
anywhere, and it must work even if the mesh is down). Every other route on that
Traefik requires a mesh source IP.

The home server has **no** inbound rule except the mesh interface. Not from the
internet, not from the LAN.

SSH has no public port on either box.

## Layers

### 1. Network edge
- **Linode Cloud Firewall**, default drop, in front of the VM. It sits outside
  the OS, so Docker's iptables rewriting can't punch through it.
- **UFW** on both hosts, default deny inbound. cloud01 allows the four ports above
  plus `wt0`; onprem01 allows only `wt0` and container→Traefik traffic.
- Exporters, SFTP and game servers on the home box **bind to the mesh IP**, not
  `0.0.0.0`, because Docker-published ports bypass UFW.

### 2. Mesh (NetBird)
- Self-hosted control plane; no third-party coordination server.
- **Login is Google SSO with an allow-list.** The OAuth app stays in Testing mode;
  only addresses on its Test users list can authenticate. 2-Step Verification is
  required on each of those accounts.
- **Default allow-all policy deleted.** Four explicit policies (see
  [netbird-policies.md](netbird-policies.md)). Friends land in `All`, which can
  reach TCP 25565 on the servers and nothing else.
- A local break-glass admin exists in NetBird's own user store in case Google is
  unavailable.

### 3. Reverse proxy (Traefik)
- `exposedByDefault: false`: a container is routed only if it opts in.
- **`mesh-only` middleware** on every admin route: `ipAllowList` for the CGNAT
  range NetBird uses. Traefik runs on host networking so it sees real source IPs;
  with published ports this rule would match nothing.
- Mesh-only hostnames have public DNS records that point at **mesh IPs**. Anyone
  can resolve them; only a peer can route to them.
- `hardening` headers on every route: HSTS, `nosniff`, frame deny, strict
  referrer, `Server` header stripped.
- TLS everywhere, including inside the mesh, from Let's Encrypt wildcard certs
  via Cloudflare DNS-01. The Cloudflare token is scoped to editing DNS on one zone.

### 4. Active blocking
- **CrowdSec** parses Traefik's JSON access log and Vaultwarden's login log
  (scenarios for HTTP CVE probes, generic scanning/brute force and Vaultwarden
  login failures). It also subscribes to the community blocklist. Decisions are
  enforced in Traefik by the bouncer plugin on the public routers, ahead of every
  other middleware. Its API listens on loopback only.
- **fail2ban** on sshd with incremental ban times. Mostly a backstop now that 22
  is mesh-only.

### 5. Host access
- `PermitRootLogin no`, `AllowUsers` one admin, `MaxAuthTries 3`, no forwarding.
- SSH reachable only over the mesh. The home server uses NetBird SSH, which ties
  shell access to the same SSO identity and policies as everything else.
- Out-of-band fallbacks that don't depend on the network: Linode's Lish console,
  and a keyboard and monitor at home.

### 6. Applications
- **Vaultwarden:** signups closed after my account was made, no admin token (so
  `/admin` returns 404), password hints off, 2FA on the account. Vault data is
  encrypted client-side regardless.
- **Grafana:** sign-up off, analytics off.
- **Containers:** `no-new-privileges` daemon-wide on cloud01; `cap_drop: ALL` on
  Traefik and Vaultwarden; non-root UIDs where images allow; config mounted
  read-only. Filebrowser can see only the dashboard's config directory.
- **Minecraft:** online mode, enforced whitelist, Java only, no RCON.

### 7. Patching
- **unattended-upgrades** for Debian, Docker and the NetBird client on both boxes.
  cloud01 reboots itself at 04:30 when a kernel needs it. onprem01 reboots weekly
  only if required *and* no players are connected.
- **Watchtower** at 04:00 for opted-in containers only. Wings is pinned to manual
  updates so it stays compatible with the Panel.

### 8. Secrets
- Every token and password lives in a `chmod 600` file on the host, never in
  compose files or this repo. Each service gets its own credential with the
  narrowest scope available (zone-scoped Cloudflare token, bucket-scoped storage
  keys, a separate key per backup bucket).
- My own credentials live in Vaultwarden. The backup encryption password is also
  stored offline, since the backups exist to restore the vault itself.

### 9. Recovery
- Nightly **restic** backups to S3-compatible object storage, encrypted
  client-side, 14 daily / 8 weekly / 12 monthly, a weekly 5 % data check, and a
  dead-man ping that alerts if a night is missed.
- NetBird's encryption key and database are backed up together; the Wings node
  token is backed up so game servers survive a rebuild.
- Restores are tested, not assumed.

## Accepted risks

| Risk | Why I accept it | Mitigation |
|---|---|---|
| Vaultwarden is public | It has to work when the mesh is down | Client-side encryption, closed signups, 2FA, CrowdSec, no admin panel |
| NetBird control plane is public | Devices must reach it to join | SSO allow-list + 2FA; CrowdSec on its routes |
| Docker socket mounted in Traefik, Watchtower, Dozzle, Wings, cAdvisor | Required for discovery, updates and game servers | Read-only where possible; none of these are on a public route except Traefik itself |
| Containers auto-update | Patch lag is the bigger risk for a one-person lab | Label opt-in, nightly backups before the update window |
| Single admin, single region | It's a homelab | Off-box encrypted backups, documented rebuild |

## Checking it

```bash
# From outside the mesh: only these should answer
nmap -Pn -p- <cloud01-public-ip>        # 80, 443, 3478/udp
curl -I https://grafana.cloud.example.com   # times out off-mesh

# On cloud01
sudo ufw status verbose
docker compose exec crowdsec cscli decisions list
docker compose exec crowdsec cscli bouncers list
sudo fail2ban-client status sshd
```
