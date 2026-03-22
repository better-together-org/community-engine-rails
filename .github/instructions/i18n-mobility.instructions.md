---
applyTo: "**/*.rb,**/*.yml,**/*.erb"
---
# I18n & Mobility Guidelines

## Keys & Locales
- Use `better_together.*` namespace for engine translations.
- Add missing keys in English first, then translate (fr, es, uk, etc).

## Mobility
- Translate model attributes; list them via helper methods.
- Store rich text translations (Action Text) where needed.
- Never rely on locale fallbacks for required content—seed defaults.

## Emails & Notifications
- Determine locale from recipient record or preference.
- Wrap copy in I18n.t calls; avoid string interpolation with HTML—use `%{}` placeholders.
