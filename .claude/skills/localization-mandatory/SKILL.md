---
name: localization-mandatory
description: Use before adding or changing any user-facing text, any model attribute a person reads (names, titles, descriptions, labels, copy), or any `translates` call, in Community Engine or a host app. Text is always localized; a change to localized attributes regenerates and commits the localized attribute diagram first.
---

# Localization is mandatory

Every string a person reads is localized. There are two places text may live, and nothing else.

| Kind of text | Where it lives |
|---|---|
| Static copy (labels, buttons, flash messages, validation errors, mail subjects and bodies, JS strings) | `I18n` keys under `better_together.*` in every locale file (en, es, fr, uk). English first, then translate; never leave a locale undefined. |
| Content a person or platform writes and stores (names, titles, descriptions, bodies, plan and tax labels) | A Mobility translated attribute, through `BetterTogether::Translatable`. Never a plain column. |

## Rules for translated attributes

1. The model does `include BetterTogether::Translatable` and declares `translates :attr, type: :string` or `type: :text`. Rich content uses `backend: :action_text`.
2. Always name the type. `string` is a short value (names, titles, labels, slugs, URLs). `text` is long copy (descriptions, bodies, JSON or markdown sources). An untyped `translates` silently takes the global default in `config/initializers/mobility.rb`, which has moved before and orphaned stored rows.
3. Changing the type of an attribute that already has rows moves data between `mobility_string_translations` and `mobility_text_translations`. Ship a migration and say so in the PR.
4. Permit the attribute and its locale accessors through `permitted_attributes`/`extra_permitted_attributes` (the concern does this for translated attributes) and use `attr_<locale>` in forms with the translation tabs.
5. Do not read the translation tables directly where a Mobility reader or the `i18n` scope works.
6. A required translated field is validated with the concern's behavior (any present locale counts); seed defaults rather than rely on fallbacks for required content.

## The diagram gate

The localized attribute diagram is `docs/diagrams/source/ce_localized_attributes.mmd` (exports under `docs/diagrams/exports`). It lists every model with translated attributes and each attribute's type, grouped by namespace. It is generated, never hand-edited.

Adding, removing or retyping any `translates` attribute, or adding a model that has one, means before the commit:

```bash
bin/export_localized_attributes          # regenerate and render
bin/export_localized_attributes --check  # read-only: fails when stale or any translates is untyped
bin/check_diagrams                       # includes the above
```

Commit the regenerated `.mmd`, PNG, SVG and `docs/diagrams/exports/.source-hashes` in the same commit as the change. The `Schema Diagrams` workflow runs the `--check` and fails the pull request otherwise. Do not commit a change to localized attributes without its diagram, and do not push with an `UNTYPED` marker in it.

The script (`scripts/localized_attribute_diagram.rb`, driven by `scripts/export_localized_attribute_diagram.rb`) reads live Mobility reflection for models and types and a static scan of `translates` calls for which calls name no type. Its specs are `spec/scripts/localized_attribute_diagram_spec.rb`.

## Host apps

The same rules apply in every host app that adds translated attributes of its own, in its models or in CE extension concerns. Such an app carries a copy of `scripts/localized_attribute_diagram.rb`, a small entry script, `bin/export_localized_attributes` and a diagram under its own docs. It draws only the app's own attributes, not the gem's, and needs no newer CE gem. An app with no translated attributes of its own has none of this. If you add the first one, copy the pair from an existing host app and add the diagram to its inventory.

## Before you commit

- No string literal a person can see sits in a view, controller, model, job, notifier or JS outside an `I18n` call or a translated attribute.
- Every new key exists in all four locale files and `bin/dc-run bin/i18n` passes.
- Every `translates` names its type.
- The localized attribute diagram was regenerated and is in the commit.
