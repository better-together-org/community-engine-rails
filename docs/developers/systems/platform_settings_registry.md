# Platform settings registry

Extension gems declare per-platform settings with `BetterTogether.register_platform_setting`. The platform form shows them on the Integrations tab, which only appears when at least one setting is registered.

## Registering a setting

```ruby
BetterTogether.register_platform_setting(
  'google_analytics.measurement_id',
  label: 'Measurement ID',
  hint: 'Looks like G-ABC123.',
  pattern: /\AG-[A-Z0-9]+\z/,
  env_fallback: 'GTAG_ID',
  group_label: 'Google Analytics'
)
BetterTogether.register_platform_setting('google_analytics.anonymize_ip', type: :boolean, default: true)
```

- Keys are `group.field`, lower case with underscores. The group becomes a fieldset on the tab.
- Types: `:string` (default), `:boolean`, `:text`, `:select` (give `options:`).
- Validation: `pattern:` (Regexp) and or `validator:` (callable returning an error message or nil). Blank values are skipped.
- `secret: true` renders a password field, never echoes the stored value and keeps it when the field is submitted blank.
- `env_fallback:` names an environment variable used only for the host platform when no value is stored. Other platforms never read it, so a hosted tenant cannot inherit the host's account.

## Reading a value

```ruby
platform.integration_setting('google_analytics.measurement_id')         # stored, else host env, else default
platform.integration_setting_source('google_analytics.measurement_id')  # :platform, :env or :default
```

Values live in `Platform#settings['integrations'][group][field]`. Unregistered keys are dropped on assignment. Registering the same key again replaces the earlier definition.

## Security notes

Secrets are stored in the settings JSON column, not encrypted. Use the registry for identifiers and switches; keep real credentials in the encrypted credential stores. Saving requires the same permission as the rest of the platform form (`manage_platform_settings`).
