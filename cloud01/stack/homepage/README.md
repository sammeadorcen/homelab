# Homepage config

Copy these into `data/homepage/` on cloud01 (drop the `.example`), replace
`example.com`, and `chown -R 1000:1000 data/homepage`. Filebrowser edits them
from the browser afterwards; Homepage picks up changes on refresh.

Passwords never go in these files. `{{HOMEPAGE_VAR_...}}` placeholders are
filled from the container's environment, which comes from `.env`.
