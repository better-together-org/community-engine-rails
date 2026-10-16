# Module 03 — Data & Conventions

This module introduces project data conventions and patterns that keep the schema consistent and readable.

## Objectives
- Use Better Together migration helpers (`create_bt_table`, `bt_*` column helpers)
- Apply string enums for human‑readable states
- Follow naming, UUIDs, and association conventions
- Write request‑first tests for model behavior

## Key Conventions
- Migrations: always use helpers from `lib/better_together/` (see AGENTS.md Migration Standards)
- Primary keys: UUID by default via `create_bt_table`
- Associations: use `bt_references` for foreign keys; maintain engine prefixing
- Enums: string enums only (never integers) with full English words
- I18n: user‑facing strings live in locale files; models support translations where applicable

## Reading List
- `AGENTS.md` → Migration Standards, String Enum Design Standards
- `docs/developers/systems/models_and_concerns.md` (if present) and relevant system docs
- `docs/diagrams/source/*_schema_erd.mmd` diagrams (events/content/etc.)

## Hands‑On Lab
- Lab 02 — Model + Migration with Tests: `./labs/lab_02_model_and_migration.md`

