---
applyTo: "**/*.rb,**/*.yml,**/Procfile,**/*.sh"
---
# Deployment: Dokku, Cloudflare, Backups

## Dokku
- One app per service; use buildpacks or Dockerfile as needed.
- Set env vars via `dokku config:set`.
- Use `ps:scale` for web/worker separation.

## Cloudflare
- DNS, DDoS, tunnels: document records & tunnel IDs.
- Cache rules must respect auth-protected pages.

## Backups
- Daily encrypted DB dumps to S3/MinIO.
- Verify restore path regularly.

## Secrets
- Store Rails master key, DB creds, etc. in Dokku/Cloudflare secrets, not repo.
