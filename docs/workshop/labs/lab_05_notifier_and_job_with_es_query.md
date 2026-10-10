# Lab 05 — Notifier + Job + ES Query

Add a small notifier and job, then run a simple ES query to validate changes.

## Objectives
- Implement or adjust a Noticed notifier delivering via Action Cable and email
- Write a Sidekiq job that enqueues based on a simple rule and logs outcomes
- Verify an ES query against indexed content

## Steps
1. Notifier:
   - Create/modify a notifier to set a localized title/body and a URL
   - Ensure `deliver_by :email` uses a parameterized mailer with localized subject
   - Add a minimal notification view partial if needed
2. Job:
   - Add a worker that finds records meeting a simple condition (e.g., events starting soon)
   - Enqueue the notifier for matching recipients; handle/ log failures
   - Make job idempotent where practical
3. ES Query:
   - Choose a searchable model; add or use an indexed field
   - Issue a simple query and validate expected hit(s)
4. Tests:
   - Add specs for notifier params and job behavior
   - If ES is mocked, use a stubbed client or scoped query expectations
5. Run: `bin/dc-run bin/ci`

## Tips
- Use existing event reminder jobs/notifiers as references
- Keep Sidekiq logs readable; prefer structured context in log messages
- For ES, keep queries minimal in tests or stub as appropriate

