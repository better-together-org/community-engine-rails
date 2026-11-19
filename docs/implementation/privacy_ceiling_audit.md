# Privacy ceiling audit: platform-state gating of visibility paths

Audited on `github/main` at 1174e04ba (before this branch). File and line numbers below refer to that
commit unless marked "now", which refers to this branch.

## Why this audit exists

`PrivacyCeilingValidatable` blocked saving a record whose `privacy` was more open than its wrapping platform
or community allowed. The product decision is to stop blocking (so public pages can be prepared behind a
private platform and released by opening the platform) and keep the original UX purpose as a warning plus an
"effective visibility" indicator.

Removing the validation is only safe if every read path already refuses to show a `public` record when its
platform or community is not public. Until now the validation made that state unreachable, so many read
paths only ever looked at the record's own `privacy`. This audit checks each path and records the result.

## Two kinds of ceiling

* Platform ceiling: the record's platform (`platform_id`) is not public.
* Community ceiling: the record's community (`community_id`) is not public, even when the platform is.

The model rule is unchanged: any non-public platform or community caps the record at `community`
(`app/models/concerns/better_together/privacy_ceiling_validatable.rb`).

## How the existing platform gate behaves

`ApplicationController#check_platform_privacy` (before_action at `application_controller.rb:32`, body at
`:143-152`) redirects an anonymous visitor to sign-in when `helpers.host_platform` is not public. Details:

* `helpers.host_platform` is `Current.platform || Platform.find_by(host: true) || <private stub>`
  (`app/helpers/better_together/application_helper.rb:285`). `Current.platform` is the platform that owns the
  request domain, falling back to the host platform (`application_controller.rb:174-183`). With several
  platforms the gate therefore follows the requesting domain, not only the host platform. Good.
* It lets through any signed-in user (`return if current_user`), not only members of that platform, and any
  robot. So on a private platform every signed-in account passes this gate and then depends on policies.
* It is skipped on purpose for: sitemaps, robots.txt, sign-in/registration/passwords/confirmations/unlocks/
  omniauth, invitations, membership requests, bot defense, agreements#show, the setup wizards and the
  federation API (grep `skip_before_action :check_platform_privacy`). Those paths must check platform state
  themselves or serve nothing sensitive.
* It is a controller filter. It does not run for Rails' own Active Storage controllers, for the JSON:API base
  controller (which uses its own authentication), for jobs, mailers or service objects.
* It only checks the request's platform, never the record's platform or community, so it cannot cover the
  community ceiling.

## Result table

"Gated" is whether the path refused to expose a `public` record whose platform or community is not public,
before this branch.

| # | Path | Gated by platform state | Evidence (github/main) |
|---|------|-------------------------|------------------------|
| a1 | sitemap.xml serving | yes (platform) | `sitemaps_controller.rb:31,38-42` returns 404 unless the platform is local and public |
| a2 | robots.txt | yes (platform) | `robots_txt_controller.rb:37,69-73` emits `Disallow: /` unless local and public |
| a3 | sitemap content generation | partial | `lib/better_together/sitemap_helper.rb:71,83,94` and `community.rb:181` filter on `privacy_public` only; platform is covered by the serve gate, community ceiling is not |
| b | search (pg_search and database backends) | partial | `search_controller.rb:21,76-83` filters backend hits through `policy_scope`, which only looked at record privacy (see g). Fallback `public_search_record?` at `:91` also privacy only. No other backend entry point exists (`grep Search.backend`) |
| c1 | JSON:API resources | partial | `api/application_resource.rb:31` uses `Pundit.policy_scope!`; auth is required (`api/application_controller.rb:25`), so no anonymous leak, but a signed-in user saw capped public rows |
| c2 | MCP resources and tools | partial | `mcp/public_communities_resource.rb:21-23` policy scope plus `where(privacy: 'public')`; tools use `policy_scope` (`search_pages_tool.rb:33`, etc.) so they inherit (g) |
| d1 | federation export | no | `content/federated_content_export_service.rb:96,109,122` exported `privacy: 'public'` rows of the local platform regardless of platform or community state |
| d2 | federation content feed and linked seeds | partial | controllers skip `check_platform_privacy` (`federation/api_controller.rb:19`) and authenticate by token; content comes from d1 |
| d3 | inbound mirrors | n/a | mirrors carry the origin's vetted privacy and are exempt from the ceiling (`privacy_ceiling_validatable.rb` `mirrored?`) |
| e1 | Active Storage proxy auth gate | no | `active_storage_security.rb:147-154` served any blob whose record `privacy_public?`; Active Storage controllers do not inherit `check_platform_privacy` |
| e2 | content-security gate | no | `content_security/active_storage_gate.rb:29` same privacy-only test |
| e3 | media cache headers | no | `media_cache_policy.rb:29` marked a capped upload as publicly cacheable |
| f | third-party tracking | partial | `third_party_tracking.rb:57-60` checks the platform (yes), but `:71` judged the record by its own privacy, so a public page in a private community counted as public |
| g1 | page, post, event, upload, calendar, checklist policy scopes (index and search) | partial | `application_policy.rb:136-148` `visible_privacy_query` trusted `privacy = 'public'`; platform handled by `check_platform_privacy` for guests, community ceiling not handled |
| g2 | `show?` for the same models | partial | `application_policy.rb:299-308` `public_or_member_scoped_community?` used raw `privacy_public?` |
| g3 | guest page scope | partial | `page_policy.rb:83` `base.published.privacy_public` |
| g4 | Joatu offers, requests, agreements; calls for interest | partial | `joatu/offer_policy.rb:56`, `joatu/request_policy.rb:78`, `joatu/agreement_policy.rb:72`, `call_for_interest_policy.rb:37` raw public tests |
| g5 | upload download | no | `upload_policy.rb:23` raw `privacy_public?` |
| h | navigation rendering (header, footer, sidebar) | partial | `navigation_item.rb:245` `visible_to?` returned true for any `public` item; shown on the pre-auth pages that skip the platform gate (sign-in, registration) |
| i1 | notifications and emails | yes (by construction) | notifiers (`app/notifiers`) target explicit recipients (invitees, members, authors) and are not selected by record privacy |
| i2 | share buttons and ICS | partial | `share_buttons ... if @page.privacy_public?` in show views (cosmetic, behind the platform gate); ICS and calendar endpoints sit behind `check_platform_privacy` and the event policy |
| i3 | RSS or Atom feeds | n/a | none exist (`grep format.rss`, `atom_feed` found nothing) |
| j | community-level privacy under a public platform | no | no read path looked at the community; only the validation did (this is the main new exposure from removing it) |

## Leak scenarios (what an unauthenticated visitor or crawler would have seen without a fix)

1. Federation export (d1). A private platform with an active peer connection and a post saved as `public`.
   The export endpoint returns the post to the peer, which stores it as a public mirror and may publish it.
   This bypasses the platform gate entirely because the federation API skips it.
2. Active Storage (e1, e2, e3). A `public` upload (or an image in a `public` page) on a private platform.
   Anyone holding the signed blob URL (copied from a page a member could see, a forwarded email, an old cached
   page) downloads it with no session. The response is also marked publicly cacheable (e3), so a CDN could keep
   it.
3. Community ceiling (j, g1, g2). A `public` post or page inside a private or community-only community on a
   public platform. An anonymous visitor reads it at its URL, finds it in search, and it is listed in the
   sitemap (a3). Before this change the validation stopped it being saved.
4. Signed-in non-member (g1, c1, c2). On a private platform, any signed-in account passes
   `check_platform_privacy`. A `public` record the platform should hold back showed in API, MCP and search
   results for that account.
5. Navigation (h). A `public` navigation item under a private platform renders on the sign-in page for
   anonymous visitors, exposing the item title and link.

The platform ceiling for ordinary HTML requests (anonymous, private platform) was already covered by the
redirect in `check_platform_privacy`; scenarios 1, 2 and 5 show the paths where that filter does not run.

## What this branch changes

* One computation, two forms: `effective_privacy` (Ruby) and `within_privacy_ceiling` (SQL), both in
  `PrivacyCeilingValidatable`. They are tested against each other.
* `ApplicationPolicy` predicates and `visible_privacy_query` use the effective privacy, so every policy that
  goes through them (g1, g2, search, API, MCP) is fixed in one place. The explicit public queries in the page,
  Joatu and call-for-interest policies were patched individually.
* Active Storage gate, content-security gate, media cache policy, third-party tracking, upload download,
  navigation visibility, share buttons, sitemap generation, MCP public communities and the federation export
  now use the effective privacy or `within_privacy_ceiling`.
* Behaviour change to note: a private platform that federates no longer exports its `public` records. This is
  deliberate (it matches what the platform shows its own guests) but operators who relied on it must open the
  platform or set records to `community` visibility intentionally.

## Not verified

* Host-app code and extension gems that read `privacy` directly (they should call `effective_privacy`).
* `ActivityPolicy::Scope` (`activity_policy.rb:23`) filters activity rows by their own privacy and then asks
  each trackable via `trackable_visible_in_activity_feed?`; I did not trace every trackable implementation.
* `PersonPolicy`, `AddressPolicy` and the contact-detail helpers filter people and contact data by their own
  `privacy`. People are not wrapped by a content ceiling (Person has no platform ceiling in the model), so I
  left them alone, but I did not review the product intent for people on private platforms.
* Real browser behaviour of the new notice and badge on every form (only helper, DOM and request level checks
  were run; screenshot capture needs `RUN_DOCS_SCREENSHOTS=1` and a JS driver).
* N+1 cost of the new effective-visibility badge on very long lists: the badge loads each row's platform and
  community. Not measured.
* Cached fragments: `cache_if` keys in the file-download block now use effective privacy, but other fragment
  caches keyed on `privacy` were not enumerated.
