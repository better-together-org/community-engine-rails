# Person profile self-serve privacy: readiness assessment (2026-10-19)

Assessed `main` at `929bb51a9`. Verdict: not ready for members to set their own profile privacy.
Profile privacy stays admin or API controlled until the criteria below are met.

## Part A: fixes to existing features (shipped for 0.11.0)

| Area | Change |
|------|--------|
| Contact details | Private contact items no longer render to other viewers |
| JSON:API | Email and preference attributes limited to the person and authorised admins |
| Messaging | Blocks stop new conversations and messages in both directions |
| Notifications | No comment, Joatu match or message notices across a block |
| Events | Visibility, RSVPs, attendee list and counts respect blocks |
| Invitations | Event, community and platform invitations refuse a blocked person, including by email |
| Abuse | Per-user throttles, tunable by environment variable |
| Docs | Profile visibility described as admin or API controlled |

## Part B: criteria before enabling self-serve publication

1. `public` is reachable: the privacy ceiling and personal-community sync are fixed and specced.
2. A profile-specific publishing agreement exists, and the blank `Current.agent` bypass in `PublicVisibilityGate` is closed for people.
3. Privacy picker in the profile form and Settings, with a plain-language preview, consent, one-click revert, and cache, sitemap and search purge on revert.
4. Private profiles on public content show a stable per-person pseudonym and generated avatar.
5. Separate opt-in `identity_disclosure` (`anonymous` default, `named`), applied through one central resolver at every touch point: mentions, bylines, event organizers, Joatu, search, conversation participants, notifications, emails, JSON:API, MCP and federated attribution.
6. Feature flag, off by default; staging first, then host apps.
7. Revisit per-field visibility, draft-event visibility, People listing public people only, and federated mirror retraction.

## Deferred

Mute (one-way, silent, private to the muter) is not defined or built; revisit after launch.
