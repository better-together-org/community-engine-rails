# Turnstile Host-App Adapter

## Overview

Community Engine `0.11.0` keeps Turnstile as an **optional host-app enhancement**, not as a required dependency for the engine baseline.

That design preserves two goals at once:

1. CE can ship a safer default without any external verification service
2. host apps can still add stronger human verification when their risk profile justifies it

## Where Turnstile fits

### Engine baseline

The engine now provides:

- signed challenge proofs
- honeypot fields
- timing checks
- replay protection
- challenge issuance throttling

### Optional host-app layer

Turnstile fits on top of that baseline when a host app needs:

- a visible human-verification step
- stronger protection against higher-volume automated abuse
- Cloudflare-backed verification signals

## Integration seam

The key pattern remains the existing captcha hook rather than a gem-owned provider hardcode.

Current hook points include:

- `BetterTogether::Users::RegistrationsController#validate_captcha_if_enabled?`
- `BetterTogether::MembershipRequestsController#validate_captcha_if_enabled?`
- the host-app registration extra-fields seam for rendering provider-specific UI where needed

The release-line bot-safety work intentionally leaves those seams in place.

## Recommended integration model

1. keep the built-in CE baseline enabled
2. add Turnstile only in the host app
3. treat Turnstile as a stronger second layer, not a replacement for the engine baseline
4. keep failure behavior explicit and user-visible

## Why this matters

If Turnstile were the only usable anti-bot path, CE would still require an external service to be production-ready. The new baseline removes that dependency while preserving a clean adapter path for deployments that need more.

## Related docs

- [Bot Safety System](bot_safety_system.md)
- [Bot Safety Operations](../../platform_organizers/bot_safety_operations.md)
- [Bot Safety Baseline](../../security/bot_safety_baseline.md)
