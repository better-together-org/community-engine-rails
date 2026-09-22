# Rack Attack Tuning

**Target Audience:** Platform organizers and operators  
**Document Type:** Administrator Guide  
**Last Updated:** March 2026

## Overview

Rack::Attack is active on this branch and is substantial enough to justify operator guidance. The configuration lives in `config/initializers/rack_attack.rb` and covers:

- global request throttling
- MCP-specific throttles
- authentication endpoint throttles
- Fail2Ban-style blocklists for common scanner and exploit patterns
- optional Redis-backed counters

## Cache store behavior

If `RACK_ATTACK_REDIS_URL` is present, Rack::Attack uses `ActiveSupport::Cache::RedisCacheStore` backed by a connection pool.

Related variables:

- `RACK_ATTACK_REDIS_URL`
- `RACK_ATTACK_REDIS_POOL_SIZE` (default `5`)
- `RACK_ATTACK_REDIS_POOL_TIMEOUT` (default `5.0`)

If `RACK_ATTACK_REDIS_URL` is not set, Rack::Attack falls back to the Rails cache store.

## Current throttle set

Global:

- `req/ip`: 300 requests per 5 minutes per IP

MCP:

- `mcp/ip`: 60 requests per minute per IP for `/mcp*`
- `mcp/tool-calls/ip`: 30 POST requests per minute for `/mcp/messages`
- `mcp/token`: 120 requests per minute per bearer token prefix

Authentication and identity endpoints:

- `logins/ip`: 5 POSTs per 20 seconds to `/users/sign-in`
- `logins/email`: 5 POSTs per 20 seconds per normalized email
- `api_logins/ip`: 5 POSTs per 20 seconds to `/api/auth/sign_in`
- `api_registrations/ip`: 3 POSTs per minute to `/api/auth/sign_up`
- `api_password_resets/ip`: 5 POSTs per minute to `/api/auth/password`
- `oauth/token/ip`: 10 POSTs per minute to `/oauth/token`
- `oauth/token/client_id`: 10 POSTs per minute per OAuth `client_id`

## Current blocklists

Immediate or progressive blocks exist for:

- `.php` requests
- WordPress and common CMS probe paths
- URL template probes such as `/blog/[year]/[slug]`
- path traversal attempts
- header or URL injection probes
- common vulnerability scanner paths such as `.env`, `.git`, `cgi-bin`, and `xmlrpc.php`

## Response behavior

Both throttled and blocklisted requests return `503` responses on this branch.

That means:

- rate-limited clients do not receive the default `429`
- logs and external monitors should treat repeated empty-body `503` responses carefully
- application operators should distinguish genuine outages from deliberate Rack::Attack responses

## Safelist

The current config safelists Better Stack monitoring user agents. If you change monitoring vendors, compare user-agent strings before adding new safelist rules.

## Tuning guidance

Start conservatively:

- raise limits only after confirming false positives in logs or support reports
- keep MCP throttles stricter than general web limits because those requests are more expensive
- keep both OAuth throttles in place; the `client_id` rule complements the IP rule
- prefer a dedicated Redis DB or instance if throttle counters should not mix with other cache traffic

## What to check during release validation

- Redis-backed counters initialize cleanly when `RACK_ATTACK_REDIS_URL` is set
- MCP clients stay below the `mcp/tool-calls/ip` threshold during expected usage
- OAuth clients do not loop into the `client_id` throttle during federation testing
- monitoring does not misclassify Rack::Attack `503` responses as generic app crashes

## Release caveat

This repo contains the Rack::Attack policy itself, but not a full operational dashboard, alert pack, or allowlist admin UI. Keep tuning changes deliberate and validate them against real logs before broadening limits.

## Related docs

- [Security Protection System](../developers/systems/security_protection_system.md)
- [External Services Configuration](../production/external-services-to-configure.md)
- [Rack Attack rate limiting flow](../diagrams/source/rack_attack_rate_limiting_flow.mmd)
