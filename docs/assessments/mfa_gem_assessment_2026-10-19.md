# MFA / TOTP / Passkey Gem Assessment for Community Engine

Date: 2026-10-19
Status: assessment only. No MFA code is proposed in this PR.
Purpose: decide whether and how CE should add multi-factor authentication, before any implementation.

## 1. Why now

- Nextcloud (cloud.btsdev.ca) enforces 2FA. When CE becomes an OIDC provider for Nextcloud and Forgejo, those services need to know whether the user performed MFA at CE, via the `amr` and `acr` id_token claims.
- CE users include people for whom account takeover or phone-number collection carries real safety risk (queer, newcomer, undocumented and Palestinian community members). The recovery design matters as much as the gem choice.
- CE currently has no MFA. `User` uses `database_authenticatable`, `omniauthable`, `registerable` and `zxcvbnable` only (`app/models/better_together/user.rb`). The gemspec sets only `rubygems_mfa_required`.

## 2. CE constraints that shape the choice

| Constraint | Source |
|------------|--------|
| Devise 5.0.4 in the lockfile; the gemspec leaves devise unpinned | `Gemfile.lock`, `better_together.gemspec` |
| Rails `>= 7.2, < 8.2` | gemspec |
| CE is an engine; the Devise model lives in the gem and host apps inherit it | `app/models/better_together/user.rb` |
| ActiveRecord encryption is already used (`encrypts` on several models) and keys exist in the dummy app credentials | `app/models`, `spec/dummy/config` |
| Locales shipped: en, es, fr, uk | `config/locales` |
| Turbo and Stimulus front end; axe-based accessibility specs are mandatory for UI | `community-engine-dev` skill, `spec/support/axe.rb` |
| Doorkeeper 5.9.3 mounted at `/api/oauth/*`, OIDC layer planned | `config/routes/api.rb` |

## 3. Candidates (data verified 2026-10-19 from rubygems.org and the GitHub API)

| Gem | Latest | Released | Runtime constraints | Repo last push | Known advisories |
|-----|--------|----------|---------------------|----------------|------------------|
| `devise-two-factor` | 6.4.1 | 2026-09-03 | devise `>= 4.0, < 6.0`; rails `>= 7.2, < 8.2`; rotp `~> 6.0` | 2026-10-08 | 4 historical (2018, 2022, 2024 x2), all in older versions |
| `devise-otp` | 2.1.0 | 2026-08-22 | devise `>= 4.8.0, < 6.0`; rails `>= 7.1`; rotp `>= 2.0.0`; rqrcode `~> 3.0` | 2026-08-22 | none found |
| `rotp` (raw) | 6.3.0 | 2023-08-30 | none | 2025-11-24 | 1 (file permissions on 6.2.1 and 6.2.2, fixed in 6.3.0) |
| `webauthn` (webauthn-ruby) | 3.4.3 | 2025-10-23 | android_key_attestation, bindata, cbor, cose, openssl, safety_net_attestation, tpm-key_attestation | 2026-09-03 | none found |
| `webauthn-rails` | 0.1.2 | 2025-10-10 | railties `>= 8` | 2026-06-12 | none found; pre-1.0 |
| `devise-passkeys` | 0.3.0 | 2023-08-19 | devise `>= 4.7.1`; warden-webauthn `>= 0.3.0` | 2024-05-04 | none found; stale |
| `two_factor_authentication` | 3.0.0 | 2026-10-01 | devise, encryptor, rails `>= 5.0`, randexp, rotp `>= 4.0` | not checked | not checked; the 2.x line was dormant from 2019 to 2026 |
| `rqrcode` | 3.2.0 | 2026-01-08 | n/a | n/a | none found |

Advisory source: GitHub advisory database, queried per gem.

### 3.1 devise-two-factor

- Compatible with CE's stack: Devise 5 allowed since 6.4.0, Rails 7.2 to 8.1 supported (the changelog lists Rails 8 and 8.1 support and drops Rails 7.0 and 7.1).
- OTP secret stored with ActiveRecord encryption (the README requires AR encryption keys). CE already runs AR encryption, so there is no new key management model.
- Replay protection: `consumed_timestep` column.
- Bundles `TwoFactorBackupable`: single-use backup codes stored as bcrypt hashes, configurable count and length, regeneration invalidates old codes.
- The gem is model and Warden strategy only. It ships no views, controllers or routes, so CE owns the UI. That is more work, but gives full control of accessibility, i18n and Turbo behaviour, and fits an engine well.
- Past advisories were about short default secrets (fixed by the 6.0 changes), brute force (rate limiting is the host's job, see section 5) and OTP reuse (fixed by `consumed_timestep`). The 6.0 upgrade notes matter only for apps migrating from older versions; CE would start on 6.x.
- Not yet verified: whether it works cleanly when the Devise model is defined inside an engine and inherited by host apps. This needs the spike in section 7.

### 3.2 devise-otp

- Active (2.0.0 in 2025-10, 2.1.0 in 2026-08), Devise 5 compatible.
- Ships controllers, routes and views, plus recovery tokens (default 10), trusted browsers (default 1 month), and a credentials refresh window.
- The bundled views and routes are the issue for an engine: they live in the `devise` namespace and need ejecting and rewriting to meet WCAG 2.2 and the four locales, so most of the UI work remains. Its bundled "trusted browser" feature adds a long-lived bypass that we would likely want off or tightly bounded.
- Smaller user base than devise-two-factor (about 122k downloads versus about 62M) and no repository `source_code_uri` in the gem metadata.
- Not verified: how the secret is stored at rest (the README matches did not show AR encryption). Treat as unknown until read from source.

### 3.3 Raw rotp plus own models

- rotp is the TOTP primitive used by devise-two-factor, devise-otp and others (about 142M downloads). It is small, dependency free and well understood. The last release is three years old, which for a stable RFC 6238 implementation is acceptable, but it means no upstream hardening work.
- Building our own models gives maximum control, but we would reimplement replay protection, backup code hashing and lockout, which devise-two-factor already gets right. Not recommended unless the spike fails.

### 3.4 Passkeys and WebAuthn

- `webauthn` (cedarcode) is the reference Ruby relying-party library: maintained, MIT, 40M downloads, no advisories found. It is server side only. The browser side should use the native `PublicKeyCredential` JSON helpers (`parseCreationOptionsFromJSON`, `toJSON`) rather than the deprecated `webauthn-json` shim. Browser support for these helpers should be confirmed during the spike.
- `webauthn-rails` is an application generator targeting Rails 8 and is pre-1.0. It is a reference, not a dependency for an engine.
- `devise-passkeys` has not been released since 2023-08 and the repo has had no push since 2024-05. Do not adopt.
- Passkeys are phishing resistant and avoid the recovery burden of a shared secret, but the recovery story (lost device) still needs backup codes or a second registered authenticator.

### 3.5 QR codes

- `rqrcode` 3.2.0 is current. QR enrolment must never be the only path: always show the base32 secret and the `otpauth://` URI as text (accessibility, and desktop-only users).

## 4. Criteria scoring

Scores: 3 strong, 2 adequate, 1 weak, ? unverified.

| Criterion | devise-two-factor | devise-otp | raw rotp | webauthn (+ own UI) | devise-passkeys |
|-----------|-------------------|------------|----------|---------------------|-----------------|
| Maintenance | 3 | 3 | 2 | 3 | 1 |
| Devise 5 and Rails 7.2 to 8.1 | 3 | 3 | 3 | 3 | ? |
| Secret encrypted at rest | 3 (AR encryption) | ? | own work | n/a (public keys) | n/a |
| Replay protection | 3 | ? | own work | 3 (sign counter) | 3 |
| Backup codes hashed | 3 | ? | own work | n/a | n/a |
| Engine friendly | 3 (no UI, no routes) | 2 (ejected views) | 3 | 3 | 2 |
| Accessibility control | 3 (we build UI) | 2 | 3 | 3 | 2 |
| i18n (en, es, fr, uk) | 3 (we build UI) | 2 | 3 | 3 | 2 |
| Phishing resistant | no | no | no | yes | yes |
| Effort | medium | medium | high | medium to high | medium |

The "?" cells are things I could not confirm from metadata or README text. They are the spike's job.

## 5. Requirements any option must meet

Accessibility (WCAG 2.2 AA):
- Code field uses `autocomplete="one-time-code"` and `inputmode="numeric"`, with a visible label and described-by help text.
- No QR-only enrolment; show the secret as selectable text with a copy button.
- No time pressure traps: explain the 30 second window, allow retry without losing form state, no auto-submit that blocks screen reader users.
- Errors announced via `role="alert"` or an `aria-live` region and moved to focus; focus management on Turbo navigations.
- Backup codes shown as plain text with a download and print option and a confirm-saved checkbox.
- Provide at least two second-factor options eventually (TOTP plus passkey or backup codes) so no single device or ability is required.
- Cover with `:accessibility, :js` feature specs using `be_axe_clean` (wcag2a, wcag2aa, wcag21a, wcag21aa, and wcag22aa where axe supports it).

Security:
- Rate limit OTP verification per account and per IP in Rack::Attack, and add lockout or progressive delay (the 2024 devise-two-factor advisory was a brute force issue).
- Replay protection via `consumed_timestep`, secret encrypted with AR encryption, backup codes hashed (bcrypt), regeneration invalidates old codes.
- Re-authentication (password) before enrolling, disabling, or regenerating codes.
- Sessions: MFA state stored server side, rotate the session id on step-up (session fixation).
- No SMS or voice codes, ever, by default (SIM swap risk and phone number collection).
- Fail closed: if encryption keys are missing, MFA enrolment errors rather than storing plaintext.

Recovery (community safety):
- Self service: backup codes generated at enrolment.
- Assisted: a platform manager can reset MFA for a verified person, with an audit record, a notification to the person's other channels, and a cooling off period. This avoids both permanent lockout and a silent bypass.
- No phone numbers, no email-only reset of the second factor.

OIDC integration:
- The id_token carries `amr` (for example `["pwd","otp"]` or `["pwd","hwk"]`) and `acr` reflecting what actually happened in the session. Nextcloud's `user_oidc` can then accept CE's MFA assertion instead of demanding a second prompt. Records `acr` per session, not per account.
- Clients (Forgejo, Nextcloud) can require a minimum `acr` via per-client policy in the claims registry.

## 6. Recommendation

1. Adopt `devise-two-factor` (6.4.x) with `TwoFactorBackupable` for TOTP and backup codes, with CE building the enrolment and challenge UI inside the engine. It is the only candidate that is actively maintained, Devise 5 and Rails 8.1 compatible, encrypts the secret with the ActiveRecord encryption CE already uses, ships replay protection and hashed backup codes, and leaves UI, accessibility and i18n fully in our hands.
2. Plan passkeys (WebAuthn via the `webauthn` gem plus a CE-owned UI) as a second phase, not the first. They are the better long-term factor, but they add a second credential model and a larger recovery surface. Do not use `devise-passkeys` (stale) or `webauthn-rails` (Rails 8 app generator, pre-1.0).
3. Do not adopt `devise-otp` unless the spike finds blocking problems with devise-two-factor in an engine. Its bundled views and trusted-browser bypass would need replacing anyway.
4. Do not build on raw rotp unless the spike fails.
5. Enable in stages:
   - Stage 1: optional for all users, with backup codes, audit trail and assisted reset.
   - Stage 2: required for platform managers and anyone holding permissions that can change roles, credentials or integrations.
   - Stage 3: required for the identity home's admins and for access to Forgejo and Nextcloud via SSO, using the `amr` and `acr` claims.
   - Stage 4: passkeys, then consider making MFA the default for all.

## 7. Verification still to do before any MFA PR (this document is not that verification)

This assessment used package metadata, repository activity, READMEs, the changelog and the GitHub advisory database. I did not install any of these gems, run a spike or run axe against a prototype. Before implementing:

1. Spike devise-two-factor in a throwaway CE worktree against the dummy app: model concern in the engine `User`, host-app inheritance, migration idempotency (`column_exists?` guards), AR encryption behaviour when keys are absent.
2. Read the devise-otp source for secret storage and recovery token hashing, to close the "?" cells.
3. Prototype the enrolment and challenge views and run axe plus a manual screen reader and keyboard pass.
4. Confirm browser support for the native WebAuthn JSON helpers for the passkey phase.
5. Check CE's Rack::Attack rules for the new endpoints and the interaction with `devise-jwt` API sign-in (API tokens must not bypass MFA for accounts that enrolled).
6. Decide `amr` and `acr` values and the claims registry hook with the OIDC provider PR.

## 8. Decisions needed from the user

- Approve the recommendation in section 6 as the basis for a spike.
- Confirm the staging order, especially whether platform managers are required to enrol in Stage 2.
- Confirm that SMS is permanently out of scope.
- Confirm the assisted reset policy (who may reset, notification, cooling off period).
