# NetBird groups and policies

Managed in the NetBird dashboard, not in files. The default allow-all policy is deleted.

## Groups

| Group | Members | How they get there |
|---|---|---|
| `admins` | My devices only | Auto-assigned to my user |
| `servers` | cloud01, onprem01 | Auto-assigned by the servers' setup key |
| `media` | The living-room Apple TV | Added by hand |
| `All` | Every peer (built in) | Automatic |

## Policies

| Name | Source → Destination | Protocol / port | Direction |
|---|---|---|---|
| `admins-everything` | `admins` → `All` | All | Bidirectional |
| `servers-to-servers` | `servers` → `servers` | All | Bidirectional |
| `everyone-minecraft` | `All` → `servers` | TCP 25565 | One-way |
| `media-to-stremio` | `media` → `servers` | TCP 443 | One-way |

`everyone-minecraft` is the whole friend-access model. Anyone who can log in at
all can reach the Minecraft port and nothing else. Who can log in is decided by
Google: the OAuth app stays in *Testing* mode and its Test users list is the
allow-list.

## Other settings

- **DNS management disabled for `servers`.** Both servers resolve through
  ordinary public DNS, so NetBird's resolver is never on the certificate-renewal
  path.
- **SSH via NetBird.** `netbird up --allow-server-ssh` plus the per-peer SSH
  toggle in the dashboard. Authenticated with the same identity as the mesh.
- **Policy identity is the full email address.** A bare username silently
  matches nothing.
