# Preflight Checklist

Use this checklist before attending Module 02.

## System
- Docker Desktop (or equivalent) installed and running
- 8 GB RAM free (recommended), 4 CPU cores available (recommended)
- Git installed; SSH keys configured (optional)
- Code editor with Markdown and Ruby support

## Repository
- Clone repository
- Install pre‑commit hooks (optional)
- Read `AGENTS.md` command guide and testing rules

## Network & Ports
- Ensure Elasticsearch, Postgres, Redis default ports are free if used directly
- Corporate proxies configured (if applicable)

## Quick Verification
- `./bin/dc-up` starts without errors
- `bin/dc-run bin/ci` runs and reports spec progress
- `bin/dc-run bin/i18n health` reports healthy or lists actionable items

