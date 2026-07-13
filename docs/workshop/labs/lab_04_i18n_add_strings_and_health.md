# Lab 04 — I18n: Add Strings & Health

Add new localized strings to a view and a notifier/mailer, then validate coverage.

## Objectives
- Add a new user‑facing string in a view and ensure it’s localized in all supported locales
- Localize a notifier/mailer title/body/subject and verify delivery strings
- Run `i18n-tasks` to normalize and ensure health across locales

## Steps
1. Identify a view or partial with hard‑coded text and replace with `t('...')` key(s)
2. Add keys to `config/locales/en.yml`, then run:
   - `bin/dc-run bin/i18n add-missing`
   - `bin/dc-run bin/i18n normalize`
   - `bin/dc-run bin/i18n health`
3. Mirror English strings to other locales (fr, es, etc.) so health passes
4. Update a notifier or mailer (e.g., EventInvitationNotifier/Mailer) to ensure title/body/subject use `I18n.t`
5. Run tests: `bin/dc-run bin/ci`

## Tips
- Prefer existing namespaces and keep key names descriptive
- Ensure interpolation variables are covered in translations
- If ActionText rich text is involved, sanitize and test plain‑text fallbacks where needed

