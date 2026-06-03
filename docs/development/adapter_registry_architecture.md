# Adapter Registry Architecture

## Purpose

Community Engine should not require third-party providers in the core gem.
Instead, CE exposes subsystem adapter contracts and host apps or thin integration gems register the concrete providers.

This keeps:

- CE focused on self-contained backends and internal workflows
- external services optional and consent-governed
- provider logic isolated behind replaceable adapters
- multi-provider fan-out possible where a subsystem should write to more than one destination

## Core Rule

The CE gem may define subsystem contracts and internal adapters.
External providers must live in host apps or thin wrapper gems.

Examples of external-provider wrapper gems:

- Sentry error reporting
- Sidekiq / Redis queue and cache integrations
- SMTP provider integrations
- S3-compatible object storage integrations
- Google analytics or search console integrations
- Cloudflare metrics or Turnstile integrations
- Formbricks survey/feedback integrations
- Nextcloud publication or collaboration integrations
- Discourse / Forem / Reddit / LinkedIn / Facebook / Instagram publishing integrations
- OpenAI and other LLM providers via `ruby_llm`
- Borgberry-mediated audited local Ollama access
- Google Maps or other mapping backends

## Built-In Subsystem Groups

The adapter registry currently reserves these subsystem groups:

- `error_reporting`
- `queue`
- `cache`
- `throttling`
- `storage`
- `smtp`
- `search`
- `metrics`
- `publishing`
- `spatial`
- `tenancy`
- `llm`
- `embeddings`
- `translation`
- `mapping`
- `federation`

These names are meant to stay stable so thin gems can target them consistently.

## Registry Behavior

Each subsystem can register multiple named providers.

Example:

```ruby
BetterTogether.register_adapter(:publishing, :ce) { |payload| ... }
BetterTogether.register_adapter(:publishing, :discourse) { |payload| ... }
BetterTogether.dispatch_to_adapters(:publishing, payload)
```

This allows:

- CE + Discourse cross-posting
- internal metrics + external metrics fan-out
- Sentry + Borgberry/Loki error fan-out

Named registrations replace prior registrations with the same name for that subsystem.

## Error Reporting

The current CE controller rescue path calls:

```ruby
BetterTogether.report_error(exception, context: ...)
```

Behavior:

- if `error_reporting` adapters are registered, all of them receive the exception
- adapter dispatch attempts every registered provider, logs individual provider failures, and only raises after fan-out completes
- if none are registered, CE falls back to `Rails.error.report`

This gives host apps a safe default while allowing thin gems to register providers like Sentry or BTS-hosted observability services.

## Thin Gem Pattern

Each external integration gem should do three things only:

1. initialize the provider client
2. register one named adapter into the CE registry
3. map CE payloads into the provider API

Example shape:

```ruby
BetterTogether.register_adapter(:error_reporting, :sentry) do |exception, context: {}|
  Sentry.capture_exception(exception, extra: context)
end
```

The same pattern can be used for:

- `:queue, :sidekiq`
- `:cache, :redis`
- `:storage, :s3_compatible`
- `:smtp, :smtp_generic`
- `:metrics, :google_analytics`
- `:metrics, :cloudflare`
- `:publishing, :discourse`
- `:publishing, :forem`
- `:publishing, :facebook`
- `:search, :ce`
- `:search, :google`
- `:llm, :openai`
- `:llm, :borgberry`
- `:embeddings, :borgberry`

## Privacy and Consent Constraints

External adapters must not silently add trackers or telemetry.

Rules for adapter gems:

- no browser trackers by default
- no pixels, embeds, or third-party scripts without explicit host consent
- no external publication or sync without explicit scoped OAuth credentials
- no over-sharing of community membership, moderation, or private draft data
- only send the minimum payload required by the provider
- keep provider-specific secrets/config outside the CE gem
- no silent fallback from audited local AI routing to a cloud provider
- AI prompts, model selections, and response metadata must remain auditable

This is especially important for corporate platforms such as Facebook, Instagram, LinkedIn, and Google services.

## AI and LLM Adapters

The current CE AI entry points now route through the adapter registry and
`ruby_llm`, but the provider extraction work is still incomplete.

The persisted robot configuration layer that selects provider/model/prompt
profiles is documented separately in
[Robot Configuration System](../developers/systems/robot_configuration_system.md).

Target architecture:

- CE defines stable `llm` and `embeddings` subsystem contracts
- CE uses `ruby_llm` as the abstraction layer instead of depending on direct `ruby-openai` calls
- provider gems register concrete LLM backends
- Borgberry is the preferred BTS-hosted audited path for local Ollama usage

Planned provider shape:

- `better_together-ruby-llm-openai`
- `better_together-borgberry-llm`

Rules:

- no external LLM provider is required by the CE gem
- no silent fallback from Borgberry/Ollama to OpenAI or another cloud provider
- tenant, platform, and community context must be preserved for authorization and audit
- prompt and response handling should support redaction and policy-aware logging
- embeddings should follow the same pattern as chat/completion calls

## Recommended Next Adapter Waves

### Wave 1

- `better_together-sentry`
- `better_together-borgberry-observability`
- `better_together-sidekiq`
- `better_together-redis-cache`
- `better_together-redis-throttling`
- `better_together-smtp`

### Wave 2

- `better_together-active_storage-s3-compatible`
- `better_together-borgberry-llm`
- `better_together-ruby-llm-openai`
- `better_together-google-metrics`
- `better_together-cloudflare-metrics`
- `better_together-formbricks`
- `better_together-nextcloud`

### Wave 3

- `better_together-discourse-publishing`
- `better_together-forem-publishing`
- `better_together-reddit-publishing`

### Wave 4

- `better_together-facebook-publishing`
- `better_together-instagram-publishing`
- `better_together-linkedin-publishing`

These later social-platform gems should go through an explicit privacy and consent review before implementation.

## Search, Translation, and Mapping

The same pattern should be applied to other subsystems over time:

- `queue`
  - Rails-native default adapter in CE
  - optional Sidekiq provider gem
- `cache` and `throttling`
  - local/file/memory defaults in CE
  - optional Redis provider gems
- `storage`
  - local Active Storage by default
  - optional S3-compatible provider gems
- `smtp`
  - local/test/bootstrap-safe mail delivery by default
  - optional platform-configured SMTP provider records
- `search`
  - internal CE search adapter
  - optional Google or external provider adapters
- `llm` and `embeddings`
  - `ruby_llm` abstraction
  - Borgberry-audited local Ollama routing
  - optional cloud-provider thin gems
- `translation`
  - internal CE/Mobility pipeline
  - future alternate translation backends
- `mapping`
  - Leaflet UI remains CE-side
  - geocoding/tile/provider integrations can be adapterized

## Current Status

Implemented now:

- generic CE adapter registry
- multi-provider error-reporting support
- host app Sentry registration moved out of controller overrides and into provider registration

Not implemented yet:

- concrete queue/cache/storage/smtp contracts
- concrete search adapter contract
- concrete metrics payload contract
- concrete publishing payload contract
- concrete llm/embeddings payload contracts
- thin wrapper gems
