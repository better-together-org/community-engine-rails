# Quota enforcement and allowances

The quota framework (`BetterTogether::Quotas`, media storage in bytes and AI translation tokens per month) used to record usage and refuse nothing. Paid entitlements now set limits and a platform can switch enforcement on, so this page says what each setting does. The ledger itself is described by `docs/diagrams/source/quota_framework_model.mmd`.

## Enforcement is per platform and per type, and off by default

A steward sets one of four modes for a quota type on their platform (`Platform#set_quota_enforcement!('media_storage', 'hard')`); it applies to every quota of that type on the platform, existing and future. The default is `shadow`.

| Mode | Usage recorded | Warns | Refuses new consumption past the limit |
|---|---|---|---|
| `off` | yes | no | no |
| `shadow` (default) | yes | no | no |
| `soft` | yes | yes (`Decision#exceeded?`) | no |
| `hard` | yes | yes | **yes** |

**Nothing already stored is ever reduced or deleted.** Lowering a limit below current usage (an allowance lapsed, a plan was downgraded) only means new uploads and new translations are refused; existing files and history stay.

## Where a refusal happens

- **Direct uploads** (`DirectUploadReservation`): before ActiveStorage issues a signed URL, the size the client declares is **held** against the quota. The check and the hold happen under the quota's lock (`Quotas.reserve!`), so two uploads racing for the last bytes cannot both be let through. A refusal is a `422` with a message and **no blob is created**. The hold is tied to the blob once it exists; a request that makes no blob releases it; an upload never attached stops counting when its time runs out (`ExpireQuotaReservationsJob`, hourly on the billing queue). A declared size above 5 GiB (`MAX_DECLARED_BYTES`) is refused outright, so one request cannot hold a whole quota. When the blob is attached, a size bigger than its hold is checked for the difference (an attach validation that fails open if the quota code errors). Settling the attachment (`AttachmentTracking`) never refuses: the work is done and the usage is a fact.
- **AI translation** (`TranslationBot`): when the owner's allowance is used up, no call is made and no tokens are spent (the result is the same "Translation unavailable" a provider with nothing to say gives). Token counts are only known after the provider answers, so a single call can overshoot the limit by its own size; the next one is refused.
- A failure in the quota code never stops an upload or a translation: it is logged, reported and counted (`Quotas.failures_today`), and the work goes ahead. A recording that fails open is a limit that is not being enforced, so the count is something to alert on. This holds in `hard` mode too: an internal error in the quota code lets the upload through, so `hard` refuses past the limit only while the quota code is working.

## Where limits come from

The limit is `the type's default` plus whatever each registered **allowance provider** adds (`Quotas::Allowances`). A provider answers `amount(owner:, type:)` and `pool?(owner:, type:)`; `Quotas.sync_limit!` writes the sum onto the quota (and the platform's mode), and is called whenever an allowance is granted, renewed, lapses or changes. Paid entitlements are the provider ([entitlements_and_allowances.md](entitlements_and_allowances.md)).

**Whose quota is charged.** Usage is charged to the content's creator, unless the content belongs to a community that has a **pool** for that type (a paid community allowance): then the community is charged, so a hosted community's members draw on its allowance, not their own.

## Data

Every quota, usage and reservation row carries the platform of its **owner** (set explicitly: a row written from a background job used to take whichever platform the code fell back to). `BackfillBetterTogetherQuotaPlatformIds` repairs rows written before this. Idempotent writes survive two writers racing for the same key: the second reads the first's row.
