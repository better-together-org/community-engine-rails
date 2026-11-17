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
   when translation genuinely works on the platform, the same gate the translate endpoint uses:
   `BetterTogether.translation_available?(platform:)` resolves the `translation` robot for the
   platform (platform-specific, else global) and checks its provider (OpenAI credentials in
   `OPENAI_API_KEY`/`OPENAI_ACCESS_TOKEN`, `ollama`, or a registered LLM adapter). With no
   translation robot the provider falls back to `BETTER_TOGETHER_LLM_PROVIDER` (default `openai`),
   so an app with only `OPENAI_API_KEY` set still qualifies. Other active robots do not count.
   See "Usage tab visibility" below for the per-owner rule.
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

## Usage tab visibility

The Person settings Usage tab, the Community usage tab and the platform admin usage overview
(Quota Grants) all list rows through `QuotasHelper#visible_quotas`, which applies two gates:

1. Platform level: `Quotas::Type.available_for?(platform)`. The quota defaults form and the grant
   form's type options use only this gate.
2. Owner level: `Quotas::Type.visible_for?(quota)`. The base class shows every row, so media storage
   behaves as before. `ai_translation_tokens` shows a row only when `Quota#effective_limit` is above 0,
   meaning the owner was granted LLM usage (an active `QuotaGrant`, else the stored limit copied from
   the defaults). A platform that sets the token default to 0 hides the meter until it grants more.

Both tabs list existing `Quota` rows only. A row is created lazily on first usage (or by
`Quotas::Backfill` from past usage), so a person or community with no token row yet sees no token
meter, even when translation is available and the default limit is above 0.

These gates control visibility only. They do not change `Quotas.check!`, which stays permissive.

## Locality gate

`Quotas.reserve!` and `Quotas.settle!` return nil for a non-local owner, `Quotas::OwnerResolver.resolve`
returns nil rather than redirecting external usage to the host platform, `Quota` and `QuotaGrant` reject
external owners, and `Quotas::Backfill` skips them and reports the count.

Diagram: [quota framework model](../../diagrams/source/quota_framework_model.mmd).
