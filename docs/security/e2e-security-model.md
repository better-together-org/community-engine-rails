# E2E Encryption — Security Model and Threat Analysis

**Feature:** Signal Protocol E2E encryption for 1:1 and group conversations
**Branch:** feat/e2e-signal-protocol
**Last updated:** 2026-03-30

---

## Release posture for 0.11.0

Community Engine `0.11.0` ships the E2EE conversation stack as a beta capability. Current code keeps the feature disabled by default unless `BETTER_TOGETHER_E2EE_MESSAGING_ENABLED` is set, and the E2EE session bootstrap is rendered from conversation surfaces rather than mounted globally from the main application layout.

Recommended activation posture:

- enable only on deployments that have explicitly opted in
- limit rollout to intended conversation surfaces and support cohorts
- describe the feature as beta / disabled-by-default, not broad general availability
- review the pending V9 and V10 follow-ups before widening rollout guidance

---

## What is protected

| Threat | Protected? | How |
|--------|-----------|-----|
| Server compromise — read stored messages | ✅ Yes | Ciphertext only; server never sees plaintext |
| Network MITM on message transit | ✅ Yes | Double Ratchet forward secrecy |
| Removed group member reading future messages | ✅ Yes | Sender key rotation on membership change (v5 fix, 2026-03-16) |
| Group replay attack | ✅ Yes | sequenceNumber high-water mark |
| X3DH session forging | ✅ Yes | SPK signature verified (V1 fix); TOFU identity registry (V2 fix) |
| OTK exhaustion DoS | ✅ Yes | Rate limit 20/30 req/hr per requester/target |
| Backup blob silent replacement | ✅ Yes | optimistic lock via previous_updated_at |
| Vendored JS supply-chain substitution | ✅ Yes | SRI integrity hash in importmap |

---

## Platform limitation: IndexedDB key storage (V7)

Private key material (identity key, signed prekey, DH ratchet keys, sender keys) is stored
in browser IndexedDB in extractable form. This is an unavoidable constraint: the Web
Cryptography API's non-extractable CryptoKey objects do not survive page reloads, so
export-to-JWK is the only viable persistence mechanism.

**This is the same architectural constraint faced by every web-based E2E chat app**
(Signal Web, WhatsApp Web, etc.).

### What this means in practice

| Scenario | Risk | Mitigation |
|----------|------|-----------|
| XSS on `app.example.com` | Can read IndexedDB and exfiltrate keys | Enforcing CSP with per-request nonces blocks script injection; any XSS must be treated as P0 |
| Filesystem access to browser profile | Raw IndexedDB files are readable | OS disk encryption (FileVault/BitLocker/LUKS) — outside app scope |
| Malicious browser extension | Can read IndexedDB | Out of scope; users must not install untrusted extensions |
| Backup passphrase brute-force | Weak passphrase → crackable backup blob | UI enforces ≥12 chars; documentation recommends ≥20 chars random |

### Active defences

- **Enforcing CSP** — inline script injection blocked without a valid per-request nonce
- **SRI on CE-JS bundle** — vendor file tampering detected by browser before execution
- **DOM plaintext cleared on disconnect** — decrypted message text does not persist in DOM
- **v1 session cache cleared on sign-out/unload** — legacy keys purged from JS heap

---

## User-facing copy requirements

The following claims are accurate and may be made:

> "Messages are end-to-end encrypted. The server never stores or accesses your plaintext
> messages or private keys."

> "Your backup passphrase is never sent to the server. It cannot be recovered if lost.
> Use a passphrase of at least 20 characters."

> "This deployment has enabled Community Engine's beta end-to-end encryption for selected
> conversations."

The following claims are **NOT** accurate and must not be made:

- ~~"Your messages cannot be read by anyone but you and your recipients"~~ — physical device
  access or browser-level compromise on the same origin can expose key material.
- ~~"Your encryption keys are protected even if your device is compromised"~~ — not true for
  web-based E2E; make no such claim.
- ~~"End-to-end encryption is enabled everywhere by default"~~ — `0.11.0` keeps the feature
  disabled by default unless a deployment explicitly opts in.
- ~~"Community Engine end-to-end encryption is generally available for all deployments"~~ —
  the current rollout posture is beta-gated and limited to selected deployments and
  conversation surfaces.

---

## Audit findings resolution

| Finding | Resolution |
|---------|-----------|
| V1 — SPK signature never verified | ✅ Fixed: SubtleCrypto.verify in initOutboundSession |
| V2 — senderIdentityKey unauthenticated | ✅ Fixed: TOFU registry in drDecrypt |
| V3 — Not X3DH | ✅ Fixed: dr_v3 sessions with 4-DH X3DH |
| V4 — OTK exhaustion DoS | ✅ Fixed: rate limit 20/30 req/hr |
| V5 — Sender key not rotated on membership change | ✅ Fixed: sender_key_version + Turbo broadcast |
| V6 — Backup silently replaced | ✅ Fixed: previous_updated_at optimistic lock |
| V7 — Keys extractable in IndexedDB | ⚠️ Platform limitation — mitigated, not eliminable |
| V8 — Group replay | ✅ Fixed: sequenceNumber + high-water mark |
| V9 — Predictable distributionId | ⚠️ Pending bundle update: vendored UMD uses a deterministic UUID pattern (`ne(conversationId)`), not `crypto.randomUUID()` |
| V10 — Zero HKDF salt | ⚠️ Pending bundle update: vendored UMD still uses `new Uint8Array(32)` (all-zeros) as the HKDF salt |
| V11 — v1 cache unbounded | ✅ Fixed: clearV1SessionCache() on sign-out/unload |
| V12 — toBase64 stack overflow | ✅ Fixed: chunked encoding |
