# External Provider Adapter Roadmap

## Goal

Community Engine should support many external systems without requiring any of them in the CE gem itself.

CE owns:

- subsystem contracts
- internal default behavior
- policy and consent boundaries
- local-first BTS integrations only when they are self-contained

Thin gems own:

- provider-specific SDKs
- OAuth/API clients
- payload mapping
- rate limiting / backoff / provider quirks

## Subsystems to Adapterize

### Error Reporting

Current state:

- generic CE adapter registry exists
- error rescue path dispatches through `:error_reporting`

Thin gems:

- `better_together-sentry`
- `better_together-borgberry-observability`

Future:

- local Loki bridge
- email/page/on-call integrations if needed

## Queue, Cache, Throttling, and Storage

Target subsystems:

- `:queue`
- `:cache`
- `:throttling`
- `:storage`

Internal/default adapters:

- Rails-native Active Job backend
- local/file/memory cache fallbacks
- local Active Storage disk service

External thin gems:

- `better_together-sidekiq`
- `better_together-sidekiq-scheduler`
- `better_together-redis-cache`
- `better_together-redis-throttling`
- `better_together-active_storage-s3-compatible`

Rules:

- CE must boot and run without Redis, Sidekiq, or S3
- Redis and Sidekiq remain supported, but not required
- jobs that require cross-process coordination must declare that requirement
- lock-dependent or throttling-dependent behavior must fail closed when no safe adapter is available

## SMTP

Target subsystem: `:smtp`

Internal/default adapters:

- local/test/bootstrap-safe mail delivery
- host-app bootstrap env fallback only when no platform SMTP provider is active

External thin gems:

- `better_together-smtp`
- future provider-specific SMTP wrappers only when they add real value over generic SMTP

Rules:

- SMTP must be platform-configurable, not silently inherited from BTS defaults
- credentials belong to platform-scoped configuration records with encrypted secrets
- management and activation must be permission-gated
- no secrets should be readable after creation outside explicit write/update flows

## Metrics

Target subsystem: `:metrics`

Internal/default adapters:

- CE-local metrics summaries
- BTS-hosted observability collectors

External thin gems:

- `better_together-google-metrics`
- `better_together-cloudflare-metrics`
- later optional privacy-preserving analytics providers

Rules:

- no external analytics by default
- no script injection or browser tracker without explicit consent
- do not leak membership or private-content data
- use server-side aggregation when possible

## Publishing

Target subsystem: `:publishing`

Internal/default adapters:

- CE native publication
- CE-to-CE federation publication

External thin gems:

- `better_together-discourse-publishing`
- `better_together-forem-publishing`
- `better_together-reddit-publishing`
- `better_together-linkedin-publishing`
- `better_together-facebook-publishing`
- `better_together-instagram-publishing`

Payload model should separate:

- canonical CE content object
- provider-safe transformed payload
- media assets
- publication scope / audience
- sync direction (`publish`, `mirror`, `refresh`, `publish_back`)

Rules:

- use OAuth/API integrations only
- no widgets, embeds, or trackers without explicit consent
- no provider receives data it does not need
- private drafts and private communities are out of scope by default
- mirrored/publication actions must remain auditable and reversible

## Search

Target subsystem: `:search`

Internal/default adapters:

- CE-native search
- BTS-hosted search backends

External thin gems:

- `better_together-google-search`
- other external search index providers if later justified

Rules:

- public content only unless explicit scoped consent exists
- never leak private community or moderation content
- respect robots/privacy/publication state

## AI, LLM, and Embeddings

Target subsystems:

- `:llm`
- `:embeddings`

Internal/default adapters:

- none required in CE core
- BTS-hosted Borgberry bridge for audited local model access

External thin gems:

- `better_together-borgberry-llm`
- `better_together-ruby-llm-openai`

Rules:

- CE should target `ruby_llm` as the provider abstraction instead of direct `ruby-openai`
- direct OpenAI usage is transitional and should move behind a thin provider gem
- Borgberry-mediated local Ollama access is the preferred BTS path
- no silent fallback from audited local routing to cloud providers
- tenant, platform, and community context must be preserved for audit and authorization
- prompts, outputs, model identifiers, and tool usage metadata should be auditable with redaction controls

## Translation

Target subsystem: `:translation`

Internal/default adapters:

- Mobility-backed content translation workflow
- CE/YAML string override mechanisms

Future thin gems:

- optional alternate translation services

Rules:

- do not force external translation services
- preserve a path for local/manual/community translation
- keep original source text and translation provenance

## Mapping and Geography

Target subsystem: `:mapping`

Internal/default adapters:

- Leaflet-based UI
- CE geography domain models

External thin gems:

- `better_together-google-maps`
- future geocoding/tile/search providers

Rules:

- UI library choice should not force vendor lock-in
- geocoding providers should be replaceable
- avoid unnecessary user-location leakage

## Federation

Target subsystem: `:federation`

Internal/default adapters:

- CE-to-CE federation
- BTS-hosted intermediaries where appropriate

External thin gems:

- platform-specific publishing/federation bridges

Rules:

- explicit scopes and agreements
- approval for publish-back directions
- least-privilege OAuth
- no sharing of internal/private community state by default

## Privacy Review Checklist For Corporate Platforms

Before enabling a provider like Facebook, Instagram, LinkedIn, or Google:

1. What exact data leaves CE?
2. What user/community consent is required?
3. Can the integration work without browser trackers or pixels?
4. Can publication happen via server-side API only?
5. Can organizers see and revoke credentials easily?
6. Can publication and sync actions be audited and reversed?
7. Does the provider receive any membership, moderation, or unpublished-content data?
8. Can the integration be disabled without breaking CE behavior?

If any answer is weak, the adapter should not ship.

## Recommended Next Build Order

1. Extract host-app Sentry use to `better_together-sentry`
2. Implement `better_together-borgberry-observability`
3. Define stable `:queue`, `:cache`, `:throttling`, and `:storage` contracts
4. Build `better_together-sidekiq`, `better_together-redis-cache`, and `better_together-redis-throttling`
5. Define a stable `:smtp` contract and platform SMTP configuration model
6. Define stable `:llm` and `:embeddings` payload contracts around `ruby_llm`
7. Build `better_together-borgberry-llm`
8. Build `better_together-ruby-llm-openai`
9. Define a stable `:metrics` event payload contract
10. Build `better_together-google-metrics`
11. Define a stable `:publishing` payload contract
12. Build `better_together-discourse-publishing`
13. Design consent/policy model for corporate publishing adapters before any implementation
