# Feedback Surface Policy Matrix

This document describes the current policy contract for the shared feedback surface introduced in the `0.11.0` line.

It separates four questions that were previously blurred together in the ellipsis-style content-actions menu:

1. who can view the record
2. who can see the feedback surface
3. who can invoke the live action
4. whether the result publishes directly or goes through review

## Current policy layers

| Layer | Current authority | Current rule |
| --- | --- | --- |
| Record visibility | record policy `show?` such as `PagePolicy#show?`, `PostPolicy#show?`, `CommunityPolicy#show?`, `PersonPolicy#show?`, `EventPolicy#show?` | A person must already be allowed to see the underlying record or block in order to encounter the feedback surface. |
| Feedback surface visibility | `BetterTogether::FeedbackPolicy#show?` | The shared feedback surface is shown when the current viewer is eligible to use the live report action. |
| Live action eligibility | `BetterTogether::FeedbackPolicy#report?` delegating to `BetterTogether::ReportPolicy#create?` | The viewer must be signed in, must resolve to a `current_person`, must target a reportable record, and must not be reporting their own content or profile. |
| Review / publication path | `BetterTogether::ReportPolicy` + `Safety::Case` creation | `Report safety issue` is a private moderation path, not a public publishing path. Creating a report does not publish new public content. |

## Live action: Report safety issue

| Question | Current answer |
| --- | --- |
| Who can see it? | Signed-in people who can already view the record and are not reporting their own content. |
| Who can use it? | The same audience that can see it, because the surface currently only renders the live action when `FeedbackPolicy#report?` passes. |
| Who can review the result? | The reporting person plus people with `manage_platform_safety`, as enforced by `ReportPolicy#show?` and the safety-case policies. |
| Does it publish publicly? | No. It creates a report and linked `Safety::Case` for review. |
| Does it require moderation? | Yes, in the sense that it routes into moderator / safety-review workflows rather than directly changing public content. |

### Current routing rule

`Report safety issue` now has an explicit routing contract:

- it is sent privately to the platform safety team
- the people who can review and act on it are platform safety reviewers
- it remains visible only to the reporting person and platform safety reviewers
- it is not automatically shared with content owners, profile owners, or community/platform content stewards

This keeps sensitive disclosures in a safety-specific lane instead of collapsing every kind of feedback into the same owner-facing workflow.

## Future actions reserved by this surface

These actions are intentionally **not live yet**, but the feedback surface is designed to host them later without inventing a second page-level UI:

- general feedback or letters to the editor
- response posts or discussion continuations
- correction suggestions
- translation improvements
- citation or accuracy revision requests

For those future actions, CE still needs explicit policy decisions for:

- who can see the action
- who can submit it
- whether submissions stay private, become member-visible, or become public
- whether publication is direct or requires review / moderation first

The intended split is:

- **safety disclosures** -> `Report` + `Safety::Case` -> platform safety reviewers
- **non-safety suggestions/corrections** -> future routed feedback workflow -> responsible stewards

## Scope labels used in the UI

The current shared feedback surface uses explicit scope labels instead of unlabeled duplicate ellipsis controls:

- `Page feedback`
- `Profile feedback`
- `Community feedback`
- `Post feedback`
- `Event feedback`
- `Section feedback`

This makes it clearer whether the action targets the entire record or a specific block/section on the page.
