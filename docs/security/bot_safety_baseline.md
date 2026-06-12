# Bot Safety Baseline

**Target Audience:** Security reviewers, maintainers, and compliance stakeholders  
**Document Type:** Security posture note  
**Last Updated:** April 2026

## Executive summary

Community Engine `0.11.0` now ships with a built-in bot-safety baseline that protects high-risk public intake paths without requiring a third-party verification service on initial deploy.

The baseline is intentionally modest and deterministic. It aims to reduce low-effort scripted abuse while remaining:

- local-first
- auditable
- compatible with host-app-specific stronger controls

## In scope

- signed challenge proof for protected forms
- hidden honeypot fields
- minimum-submit timing checks
- replay protection
- challenge issuance throttling
- scoped first-party robot access for explicit machine principals

## Out of scope

- behavioral scoring across long histories
- third-party reputation feeds
- invisible challenge scoring from external providers
- guarantees against every spam or abuse attempt

## Threats addressed

The baseline helps with:

- direct scripted POST attempts against public forms
- simplistic browser automation
- repeated resubmission of captured proof material
- accidental broad machine access through undocumented scraping

## Threats not fully solved

Additional controls may still be needed for:

- sophisticated human-assisted abuse
- distributed attacks across many IPs and devices
- adversaries willing to simulate realistic browser timing
- host apps facing sustained targeted registration abuse

## Control layering

### Engine baseline

Always available after this change:

- Rack::Attack throttles
- signed form proof
- honeypot + timing + replay checks
- first-party robot token scopes

### Optional host-app enhancement

Still available when needed:

- Turnstile through the existing captcha seam

This preserves a local-first deploy story while allowing stricter host-app posture where necessary.

## Review artifacts

- [Submission defense flow](../diagrams/exports/png/bot_defense_submission_flow.png)
- [Robot access flow](../diagrams/exports/png/bot_robot_access_flow.png)
- [Operator decision flow](../diagrams/exports/png/bot_safety_operator_decision_flow.png)
- [0.11.0 bot safety summary](../releases/0.11.0_bot_safety_summary.md)

