# Quota Default Limits

Starting limits for new quotas are configuration, not code. Only **local** owners get
quotas: a local platform (`Platform#external` is false), and the people and communities
that live on one. Federated peers, OAuth providers and anyone mirrored from them never do
(`BetterTogether::Quotas::Locality`).

## Current defaults

| Quota type | Person | Community | Platform | Unit |
|---|---|---|---|---|
| `media_storage` | 250 MB | 1 GB | 10 GB | bytes, cumulative |
| `ai_translation_tokens` | 50,000 | 50,000 | 50,000 | tokens per month |

## Where the numbers come from

Resolution order, first present value wins (`BetterTogether::Quotas::Defaults.for`):

1. The owning platform's override, edited on the platform edit screen (Host Dashboard,
   Platforms, Edit, "Quota defaults") and stored in `Platform#settings['quota_default_limits']`.
   For a platform owner this is the platform itself; for a person or community it is the
   platform they live on. Byte quotas (media storage) are chosen from a slim-select of decimal
   sizes (100 MB up to 10 TB, shown as e.g. "250 MB"); "Use default" means "inherit". The
   controller rejects any byte value that is not a listed step or the configured default.
   The "AI LLM usage tokens per month" block (and its usage meters and grant options) only appears
   when an AI provider is configured: RubyLLM has an OpenAI token, or an active robot is
   available to the platform (`Quotas::Type.available_for?`).
2. The host app's `config/quota_defaults.yml`.
3. Any other engine's `config/quota_defaults.yml`, by engine name.
4. The gem's `config/quota_defaults.yml`.

Files are deep-merged, so a host app lists only what it changes:

```yaml
# host app config/quota_defaults.yml
quotas:
  media_storage:
    person: 500000000   # 500 MB
```

Owner kinds are `person`, `community` and `platform`. Values must be non-negative integers;
an unknown kind or a bad value raises `Quotas::Defaults::InvalidDefaultsError` at first use.

## When a change takes effect

- A `Quota` row is created lazily on first usage and copies the default into `limit` at that moment.
- Changing a platform's quota defaults enqueues `Quotas::ApplyPlatformDefaultsJob`, which updates the
  existing quotas of that platform's local people, communities and the platform itself. Usage and
  balances are never modified, and `QuotaGrant` overrides are separate records and are untouched.
- Changing a YAML file only affects quotas created afterwards. To move existing quotas to the new YAML
  values, ship a data migration like `20261110230000_apply_configured_quota_defaults_to_existing_quotas.rb`
  (it updates local owners only and leaves external-owner quotas alone).

## Locality gate

`Quotas.reserve!` and `Quotas.settle!` return nil for a non-local owner, `Quotas::OwnerResolver.resolve`
returns nil rather than redirecting external usage to the host platform, `Quota` and `QuotaGrant` reject
external owners, and `Quotas::Backfill` skips them and reports the count.

Diagram: [quota framework model](../../diagrams/source/quota_framework_model.mmd).
