# End-to-End Encryption Rollout

**Target Audience:** Platform organizers  
**Document Type:** Operator guide  
**Last Updated:** March 2026

This guide explains the operational model for the Signal-based end-to-end encryption (E2E) conversation feature in the `0.11.0` release lane.

## Release posture in 0.11.0

In `0.11.0`, E2EE messaging should be treated as a beta capability, not general availability. Current code checks `BETTER_TOGETHER_E2EE_MESSAGING_ENABLED` before enabling the messaging path, and the E2EE session bootstrap is rendered from conversation UI rather than mounted globally from the main application layout.

Activation should therefore be limited to deployments that have explicitly opted in and to conversation surfaces where the rollout has been intentionally reviewed.

## What the feature does

The E2E messaging feature moves message confidentiality to the client side:

- conversation messages can be encrypted in the browser before upload
- the server stores ciphertext and delivery metadata
- private keys stay on user devices and are never sent to the server
- encrypted key backups can be stored on the server, but only in passphrase-encrypted form

## What the server still does

The server remains responsible for:

- storing encrypted message payloads
- distributing public prekey bundles
- storing encrypted backup blobs and salts
- enforcing authorization and rate limits
- managing conversation membership changes that trigger sender-key rotation

The server does **not** hold plaintext message content or user private keys for this feature.

## Main implementation surface

Relevant files:

- `app/helpers/better_together/application_helper.rb`
- `app/views/layouts/better_together/application.html.erb`
- `app/views/better_together/conversations/_conversation_content.html.erb`
- `app/views/better_together/messages/_form.html.erb`
- `app/views/better_together/e2e/_session_bootstrap.html.erb`
- `app/models/better_together/message.rb`
- `app/models/better_together/person.rb`
- `app/controllers/better_together/api/v1/prekeys_controller.rb`
- `app/javascript/controllers/better_together/e2e_session_controller.js`

Current behavior to understand before rollout:

- `BETTER_TOGETHER_E2EE_MESSAGING_ENABLED` is the top-level deployment gate
- the main application layout no longer mounts the E2EE bootstrap globally
- conversation content renders the E2EE bootstrap only when the helper gate passes for the current person
- the message form attaches E2EE behaviors only when the same feature gate is enabled

The `Message` model exposes:

- `e2e_encrypted`
- `e2e_version`
- `e2e_protocol`

The `Person` model stores public-key and encrypted-backup metadata such as:

- `identity_key_public`
- signed prekey fields
- registration ID
- encrypted key backup blob and salt

## User lifecycle

### First device

On the first device, the browser:

1. generates a local identity
2. registers public prekeys with the server
3. prompts the user for a backup passphrase
4. uploads an encrypted key backup if the user supplies one

### New device

On a new device, the browser:

1. checks whether a server-stored encrypted backup exists
2. prompts for the passphrase
3. restores keys into local IndexedDB if the passphrase is correct
4. re-registers public key material with the server

### Lost passphrase

Lost passphrases are a hard recovery boundary. Old encrypted messages remain inaccessible. Operators should not imply that the platform can recover those keys.

## Membership changes and group behavior

Conversation membership changes are security-sensitive.

`ConversationParticipant` callbacks bump the conversation’s `sender_key_version`, which triggers the client to rotate group sender keys. This prevents removed participants from reading future encrypted messages.

Operators should treat this as expected behavior, not a bug:

- newly added participants do not magically gain access to earlier encrypted group history
- removed participants cannot read future encrypted traffic after rotation

## Plaintext fallback behavior

The message form now stays disabled while the current user's local key session is still initializing (for example, during first-device key generation or encrypted-backup restore). This avoids a first-visit race where an opted-in deployment could submit plaintext before the browser had finished preparing the local E2EE identity.

After that local bootstrap is complete, the feature still degrades gracefully when required participant key material is missing. In that case, messages may fall back to plaintext instead of failing hard.

This is important operationally because it means:

- a support ticket about “why was this message not encrypted?” may reflect missing participant prekeys, not delivery failure
- operators should monitor onboarding and key-registration health, not just message transport
- opted-in deployments may still have mixed encrypted and plaintext conversation states during rollout

## Prekey and backup API behavior

`PrekeysController` provides:

- `GET /api/v1/people/:id/prekey_bundle`
- `PUT /api/v1/people/:id/register_prekeys`
- `GET /api/v1/people/:id/key_backup`
- `PUT /api/v1/people/:id/key_backup`

Important protections include:

- authenticated access requirements
- rate limiting on prekey bundle retrieval
- idempotent key registration
- optimistic locking for backup updates with `previous_updated_at`
- size and base64 validation for backup blobs

## Operational caveats

### 1. No admin decryption path

Platform organizers cannot use the server to decrypt user message content. This is by design.

### 2. Browser compromise still matters

The security model doc is explicit that browser-side compromise, especially XSS on the same origin, can expose locally stored key material. Strong CSP and frontend integrity controls remain critical.

### 3. Device-bound storage

Keys live in browser storage and are restored through encrypted backup, not by server-side plaintext recovery.

### 4. Rate limits are intentional

Prekey bundle access is rate-limited to reduce one-time-prekey exhaustion attacks. If you see 429 responses around key setup, investigate whether this is a misbehaving client, a rollout surge, or an abuse pattern.

### 5. Pending bundle follow-ups remain tracked

The security model still tracks V9 and V10 as pending bundle-level follow-ups. These findings do not require alarmist product messaging, but they are part of why the `0.11.0` posture remains beta-gated and explicitly opt-in.

## Rollout checklist

- enable `BETTER_TOGETHER_E2EE_MESSAGING_ENABLED` only on deployments that have explicitly opted in
- verify only intended conversation surfaces render the E2EE bootstrap and message-form integration
- verify key generation and registration on a fresh account
- verify encrypted backup creation and restore on a second browser/device
- verify group membership change rotates the sender key version
- verify support staff understand that passphrases cannot be recovered
- review CSP posture, frontend integrity assumptions, and the pending V9/V10 notes in the security model
- avoid release messaging that implies the feature is broadly enabled or generally available

## Related docs

- [E2E security model](../security/e2e-security-model.md)
- [Conversations messaging system](../developers/systems/conversations_messaging_system.md)
- [0.11.0 Release Overview](../releases/0.11.0.md)

## Diagram

- [E2E encrypted conversation flow](../diagrams/source/e2e_encrypted_conversation_flow.mmd)
