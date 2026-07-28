# better_together-borgberry

Optional Community Engine extension providing:

- **C3 Tree Seeds** — a peer-to-peer community contribution token system (`BetterTogether::C3::*`), including
  a cross-platform federation token-seed layer and the Joatu settlement bridge (`Joatu::Settlement`,
  `Agreement#fulfill!`/`cancel!` C3 side-effects).
- **Borgberry fleet integration** — fleet-node registration, ownership, and compute-contribution tracking
  (`BetterTogether::Fleet::*`, `BetterTogether::AgentJobResult`), plus a portable `borgberry_did` identity
  on `Person`.

Not bundled with core CE by default — this is a separate gem so hosts that don't use C3/Borgberry carry
none of this code, its migrations, or its routes.

## Docs

See `docs/c3/`, `docs/c3-federation-design.md`, `docs/c3-contribution-integration-design.md`,
`docs/c3-blockchain-analysis.md`, and `docs/borgberry-ce-integration.md` in this gem.

## How it wires into a host CE app

Core CE carries no direct reference to any class in this gem. Instead, this engine reaches into the host
at boot:

- `ModelRegistry#apply_model_decorations!` — prepends decoration modules onto `BetterTogether::Person`,
  `BetterTogether::PlatformConnection`, and `BetterTogether::Joatu::Agreement` (see
  `app/models/concerns/better_together/borgberry/decorations/`). `Joatu::Agreement` in particular relies on
  three no-op extension-point methods core defines (`after_accept_side_effects`, `complete_pending_settlement!`,
  `cancel_pending_settlement!`) that this gem overrides via `prepend` + `super`.
- `BetterTogether.api_v1_routes_extension` / `BetterTogether.federation_routes_extension` — chains this
  gem's `namespace :c3`/`:borgberry`/`:fleet` API routes and federation `c3/token_seeds`/`c3/lock_requests`
  routes onto whatever a host app's own initializer already set. **If your host app sets either of these
  itself, do so in an initializer that also chains onto the existing value** (`existing = BetterTogether.x; BetterTogether.x = proc { instance_exec(&existing) if existing; ... }`) rather than reassigning outright, or a
  later-loading extension's routes will be silently dropped. This mechanism only safely composes two
  writers when both chain; it does not yet support N independent writers out of the box.
- `BetterTogether::FederationScopeAuthorizer.register_scope_rule('c3.exchange')` — registers the
  `PlatformConnection#allows_c3_exchange?` check for the `c3.exchange` federation OAuth scope.
- `Joatu::AgreementsController.rescue_from(C3::Balance::InsufficientBalance)` — restores the
  plain-language "insufficient balance" flash message on `accept!`/`fulfill!` failures.

## No organizer-facing UI ships in this round

`PlatformConnection#allow_c3_exchange`/`c3_exchange_rate` are settable via the model (and this gem's own
future controllers), but the shared `platform_connections/_form.html.erb` partial in core no longer renders
a Tree Seeds exchange fieldset — that UI was removed as part of the extraction pending a dedicated
settings surface owned by this gem.

## Migrations

Install into a host app the normal Rails engine way once you add a generator, or copy `db/migrate/*`
manually. All migrations are idempotent (`table_exists?`/`column_exists?` guarded) per CE convention.

## Governance note

C3 balances have no effect on voting weight. One-member-one-vote is a firm architectural decision —
community economic participation (Tree Seeds) is deliberately separated from democratic participation.
See `docs/c3/04-regulatory-considerations.md`.
