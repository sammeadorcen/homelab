# meador.dev

Plain HTML and one stylesheet. No build step.

| File | Page |
|---|---|
| `index.html` | Front page |
| `about.html` | About |
| `docs.html` | Homelab docs and security rundown |
| `_headers` | Security headers (CSP, HSTS) applied by Cloudflare Pages |

Deploy: Cloudflare Workers Builds (see `../wrangler.jsonc`). Deploy command `npx wrangler deploy`, no build command.
