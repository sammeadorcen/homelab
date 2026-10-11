# meador.dev

Plain HTML and one stylesheet. No build step.

| File | Page |
|---|---|
| `index.html` | Front page |
| `about.html` | About |
| `docs.html` | Homelab docs and security rundown |
| `_headers` | Security headers (CSP, HSTS) applied by Cloudflare Pages |

Deploy: Cloudflare Pages → connect this repo → framework preset **None**, build
command empty, output directory `site`. Pages serves `docs.html` at `/docs`.
