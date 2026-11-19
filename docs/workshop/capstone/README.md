# Capstone — End‑to‑End Feature

Build and deploy a small feature from spec to production, demonstrating TDD, i18n, security, and operability.

## Objectives
- Design and implement a scoped feature (1–2 models or UI dimensions, not a rewrite)
- Follow TDD (acceptance criteria → failing tests → minimum code → refactor)
- Provide i18n coverage and security checks
- Deploy to staging (or Dokku) and demonstrate end‑to‑end behavior

## Example Project Ideas
- Events: add an “attending with guests” count field with validation + UI + tests
- Search: add a simple filter/sort for events or posts; include ES query and tests
- Notifications: add an organizer-only reminder notifier for a new action
- I18n: transform a small feature’s text surfaces into fully localized strings, including mailers

## Deliverables
- Short design note: intent, scope, data changes (if any), risks
- Tests (request/model/job/notifier as applicable)
- Feature implementation and localized strings
- Deployment notes (env/secrets, migration plan if any)
- Demo walkthrough and logs/screenshots

## Timeline
- Week 6: Pick and scope; write acceptance criteria
- Week 7: Implement with tests; mid‑week check‑in
- Week 8: Deploy; demo; peer feedback

