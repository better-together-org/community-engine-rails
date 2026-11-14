# Bot Safety Operations

**Target Audience:** Platform organizers, operators, and trusted administrators  
**Document Type:** Operations guide  
**Last Updated:** April 2026

## Overview

Community Engine `0.11.0` now ships with a built-in, local-first bot-safety baseline. It is designed to make a fresh CE deployment safer **before** any host app adds Turnstile or another external verification service.

The baseline currently covers:

- registration
- membership requests
- safety reports
- first-party robot access to public, community, and private content through scoped tokens

## Built-in controls

### Human submission protection

Protected forms now use:

- signed challenge tokens
- honeypot fields
- minimum submit timing
- replay protection
- challenge issuance throttling

### Authorized robots

Community Engine now also supports first-party robot principals through `BetterTogether::Robot`.

Robots use:

- `X-Better-Together-Robot-Token`
- a token format of `<identifier>.<secret>`
- a digest stored in robot settings
- explicit scopes such as:
  - `read_public_content`
  - `read_community_content`
  - `read_private_content`
  - `submit_public_forms`
  - `submit_authenticated_forms`

## Operational boundaries

### What the built-in baseline is good for

- reducing low-effort scripted abuse
- protecting the most exposed public intake forms on first deploy
- giving host apps a safer default before external integrations are added
- supporting explicit robot access instead of undocumented scraping

### What it does **not** do by itself

- advanced bot scoring
- reputation intelligence
- third-party challenge enforcement
- risk-based trust decisions across multiple sessions or devices

## When to add Turnstile

Turnstile is still optional, but it becomes a strong next step when:

- a host app is under active automated abuse
- signup or request abuse remains high after the built-in baseline
- the operator is comfortable depending on an external service for stronger human verification

Use the built-in baseline as the floor. Use Turnstile when your threat level or operational context justifies the extra dependency.

## Troubleshooting checklist

### People say real submissions are being rejected

Check:

1. whether the form was left open too long
2. whether browser automation or aggressive autofill was involved
3. whether the same form was resubmitted using stale page state
4. whether challenge issuance is being rate-limited upstream

### A robot token is failing

Check:

1. the token header is present
2. the token uses `<identifier>.<secret>`
3. the robot has bot access enabled
4. the digest and scope list are present in settings
5. the requested path matches the granted privacy scope

## Visual and technical references

- [Bot Safety System](../developers/systems/bot_safety_system.md)
- [Turnstile host-app adapter](../developers/systems/turnstile_host_app_adapter.md)
- [Bot Safety Baseline](../security/bot_safety_baseline.md)
- [Support troubleshooting guide](../support_staff/bot_safety_troubleshooting.md)
- [Submission defense flow diagram](../diagrams/exports/svg/bot_defense_submission_flow.svg)
- [Robot access flow diagram](../diagrams/exports/svg/bot_robot_access_flow.svg)
- [Operator decision flow diagram](../diagrams/exports/svg/bot_safety_operator_decision_flow.svg)
