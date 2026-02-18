# Module 05 — I18n & UI (Mobility, ActionText, Stimulus)

This module focuses on internationalization (i18n) and the UI layer (ERB, Turbo partials, Stimulus).

## Objectives
- Use Mobility + ActionText for translatable content
- Maintain locale coverage with `i18n-tasks`
- Apply UI conventions with Stimulus controllers and progressive enhancement
- Ensure user‑facing strings are fully localized

## Topics
- Mobility basics: translated attributes and rich text fields
- i18n workflow: normalize, missing, add‑missing, health
- Views: ERB + partials, Turbo‑stream responses for small interactions
- Stimulus: targets/actions, unobtrusive behavior binding; safe DOM updates
- Email and Noticed templates: localized titles/bodies/subjects

## Commands
- Normalize: `bin/dc-run bin/i18n normalize`
- Find missing: `bin/dc-run bin/i18n missing`
- Add missing: `bin/dc-run bin/i18n add-missing`
- Health: `bin/dc-run bin/i18n health`

## Reading List
- `AGENTS.md` → Translations & Locales, Translation Normalization & Coverage
- `docs/developers/systems/i18n_mobility_localization_system.md`
- Example: invitation notifiers/mailers for localized copy

## Hands‑On Lab
- Lab 04 — I18n: Add Strings & Health — `./labs/lab_04_i18n_add_strings_and_health.md`

