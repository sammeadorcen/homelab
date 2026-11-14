# Proxmox

`cloud-init/debian13-vendor.yaml` is the first-boot setup for every VM cloned
from the Debian 13 template (VM 9000). It applies the same baseline as
onprem01: hardening sysctls, unattended upgrades with a weekly conditional
reboot, Docker with log rotation and live-restore, the docker-socket-refresh
fix, the NetBird client (not logged in), and a deny-by-default UFW that only
admits the mesh plus a temporary bootstrap SSH rule.

The template uses Debian's `generic` cloud image (not `genericcloud`) so the
full kernel's Intel graphics driver is there for Quick Sync passthrough.
