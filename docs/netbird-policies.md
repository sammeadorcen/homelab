# NetBird groups and policies

Managed in the NetBird dashboard, not in files. The default allow-all policy is deleted.

## Groups

| Group | Members | How they get there |
|---|---|---|
| `Admins` | My PCs, phone and tablet | Auto-assigned to my user accounts |
| `servers` | cloud01, onprem01 | Setup key (now revoked) |
| `Media` | The living-room Apple TV | Added by hand |
| `All` | Every peer (built in) | Automatic |

Friends' accounts have no auto-groups, so their devices are only in `All`.

## Policies

| Name | Source → Destination | Protocol / port | Direction |
|---|---|---|---|
| `admins-everything` | `Admins` → `All` | All | One-way |
| `servers-to-servers` | `servers` → `servers` | All | Bidirectional |
| `everyone-minecraft` | `All` → onprem01 (peer) | TCP 25565 | One-way |
| `media-to-onprem01` | `Media` → onprem01 (peer) | TCP 443 | One-way |
| `SSH Access` | `Admins` → `All` | NetBird SSH, port 22 | One-way |

`admins-everything` is one-way on purpose: a bidirectional rule from `Admins` to
`All` would also let every friend's device open connections to my devices.

`everyone-minecraft` is the whole friend-access model. Anyone who can log in at
all can reach the Minecraft port on onprem01 and nothing else; cloud01 isn't a
destination at all. Who can log in is decided by
Google: the OAuth app stays in *Testing* mode and its Test users list is the
allow-list, and new users also need approval in NetBird.

The Apple TV gets HTTPS to onprem01 only (AIOStreams/Stremio behind Traefik),
plus the Minecraft port every peer has.

## Other settings

- **DNS management disabled for `servers`.** Both servers resolve through
  ordinary public DNS, so NetBird's resolver is never on the certificate-renewal
  path.
- **SSH via NetBird.** `netbird up --allow-server-ssh` on the servers plus the
  `SSH Access` policy (protocol `netbird-ssh`). The legacy per-peer SSH toggle
  stays off. Authenticated with the same identity as the mesh.
- **Policy identity is the full email address.** A bare username silently
  matches nothing.
