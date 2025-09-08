# Facilitator Notes — 3‑Hour Intro Workshop

Use this as a timeboxed guide for the mixed developer/IT audience. Keep energy high and focus on actionable understanding with clear jump‑offs to deeper modules.

## Agenda (180 minutes)
- 0:00–0:05 — Welcome, logistics, goals
- 0:05–0:15 — Course map and outcomes (Module 00)
- 0:15–0:55 — Big‑Picture Architecture (Module 01)
  - 0:15–0:35 — Diagram walkthrough (services, data flows, privacy gates)
  - 0:35–0:55 — Q&A + jumping‑off paths into systems docs
- 0:55–1:30 — Repo & Conventions + Live Local Walkthrough
  - 0:55–1:10 — Conventions (enums, migrations, policies, i18n)
  - 1:10–1:30 — Start services, run tests, inspect logs/Sidekiq
- 1:30–1:40 — Break
- 1:40–2:10 — Events + Invitations High‑Level Tour
  - Show representative flows (models, policies, tokens, notifiers, Stimulus, i18n)
- 2:10–2:35 — Guided Lab: Hello Engine (Lab 01)
  - In pairs; facilitator floats for unblockers
- 2:35–2:55 — Wrap‑up & Next Steps
  - Preflight checklist homework; skim Module 02/03
- 2:55–3:00 — Final Q&A / Parking lot

## Materials Checklist
- Slides or printed agenda
- Links handy:
  - Workshop index: `docs/workshop/index.md`
  - Big‑Picture diagram: `docs/diagrams/exports/*/platform_technical_architecture.*`
  - Commands cheat sheet: `docs/workshop/cheat_sheets/commands_cheat_sheet.md`
  - Lab 01: `docs/workshop/labs/lab_01_hello_engine.md`

## Live Demo Script (suggested)
- Open the TOC and workshop index; frame the course
- Show the big‑picture diagram; emphasize privacy gates and background jobs
- Terminal:
  - `./bin/dc-up`
  - `bin/dc-run bin/ci`
  - `bin/dc-run bin/i18n health`
  - `./bin/render_diagrams --force` (if time permits)
- App:
  - Load home page; briefly show an event and RSVP buttons
  - If available, visit `/sidekiq` as a platform manager

## Common Pitfalls & Remediations
- Missing `bin/dc-run`: remind that anything touching DB/Redis/ES needs it
- RSpec `-v` confusion: use `--format documentation` for detailed output
- Controller vs request specs: default to request specs in engines
- i18n gaps: run `bin/dc-run bin/i18n add-missing` then translate

## Backup Plans
- If Docker resources are constrained, demonstrate on facilitator machine and hand out lab steps
- If ES is unavailable, skip ES step and acknowledge it will be covered in Module 06

## Discussion Prompts
- Which components matter most for your role (IT vs dev)?
- Where would you add monitoring first in your environment?
- What’s your policy for feature flags and incremental rollout?

## Homework Reminders
- Complete Preflight Checklist
- Skim Module 02 & 03
- Optional: try Lab 02 setup and bring questions

