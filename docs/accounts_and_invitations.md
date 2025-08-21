# Accounts, Invitations, and Agreements

This guide explains user account flows (Devise), platform invitations, required agreements, and how `User` relates to `Person`.

## Core Concepts

- `BetterTogether::User`: Devise-authenticated account (email/password, confirmable, recoverable, rememberable, JWT).
- `BetterTogether::Person`: Profile/identity used across the app (creator of content, recipient of notifications, memberships, etc.).
- Identification link: A join (`BetterTogether::Identification`) connects `User` (agent) to `Person` (identity):
  - `User has_one :person_identification` (active), `has_one :person, through: :person_identification`.
  - `Person has_one :user_identification`, `has_one :user, through: :user_identification`.

## Required Agreements at Sign-up

- Agreements (seeded via `AgreementBuilder`): `privacy_policy`, `terms_of_service`, optionally `code_of_conduct`.
- On the Devise sign-up page:
  - Required checkboxes shown if agreements exist.
  - `Users::RegistrationsController` blocks submission unless required agreements are checked.
  - After successful sign-up, `AgreementParticipant` records are created for the new `Person` for each required agreement (with `accepted_at`).

## Registration (Public vs Private Platform)

- Public: user completes sign-up and is signed in; confirmation email is sent (Devise confirmable).
- Private platform:
  - After sign-up (inactive), redirects to sign-in page; confirmation required before access.
- In both cases:
  - A `Person` is created via nested params/build helper.
  - Memberships are created:
    - Adds the person to the host community with role `community_member` (or role from an invitation, see below).

## Invitations Flow

- Platform managers can create `PlatformInvitation` records for a platform.
  - Validations: locale required, unique email per platform; throttling on inviter; status transitions pending→accepted.
  - After create: an invitation email is queued with a unique token URL.
- Accepting an invitation:
  - A user visiting the invitation URL lands on the Devise sign-up form with email prefilled.
  - On successful sign-up and confirmation of agreements:
    - Person is added to the host community with the invitation’s `community_role`.
    - If present, person is added to the host platform with the invitation’s `platform_role`.
    - The invitation is marked accepted, linking the `invitee` to the new `Person`.

## Passwords and Sessions (Devise)

- Sign-in/out: handled by Devise sessions controller.
- Confirmations: Devise confirmable module sends confirmation email on registration.
- Password reset: Devise passwords controller handles reset requests and emails.

## Relationship: Users and People

- A `User` represents credentials and login state; a `Person` represents the human identity used across the system.
- Most domain actions (offers/requests/messages/etc.) are authored by `Person`, not `User`.
- Authorization & permissions are evaluated on `Person` memberships and roles.
- Notifications are addressed to `Person` (recipient in Noticed).
- A `User` delegates permission checks to its `Person` (`user.permitted_to?`).

## Post-registration Side Effects

- Community membership: new `Person` is added to the host community (role from invitation or default `community_member`).
- Platform membership: added only if the invitation specified a platform role.
- Agreements: `AgreementParticipant` rows created.

## Diagram

See the Mermaid diagram in `accounts_flow.mmd` for the end-to-end flows.

