# Community Engine — Intro Workshop

> Audience: Developers + IT • Duration: 3 hours

---

## Course Map & Outcomes

- Modules, labs, capstone, office hours
- Goal: from local dev → production ops

---

## Architecture Overview

![Platform Technical Architecture](../../diagrams/exports/png/platform_technical_architecture.png)

Notes:
- Web app, jobs, Action Cable, DB/PostGIS, ES, Redis, Storage, Email

---

## Privacy & Authorization

- RBAC (roles/permissions)
- Platform privacy modes
- Invitation tokens (platform vs event)

---

## Repo & Conventions

- Rails engine layout; concerns
- String enums; migration helpers
- Request‑first testing; i18n rules

---

## Live Local Walkthrough

- `./bin/dc-up`
- `bin/dc-run bin/ci`
- `bin/dc-run bin/i18n health`
- Sidekiq Web UI

---

## Events + Invitations (Thread)

- Models, policies, tokens
- Notifiers + mailers
- Stimulus UI & Turbo

---

## Lab 01 — Hello Engine

- Verify services and tests
- Render diagrams

---

## Next Steps & Homework

- Preflight checklist
- Skim Modules 02–03
- Optional: start Lab 02

