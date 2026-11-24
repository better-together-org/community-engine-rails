# CE billing assessment, November 2026

Subject: Community Engine branch `feature/billing` at commit `26e283cb8`, plus an assessment of the old PR #1581 work (section 4).
Billing is greenfield: nothing billing-related is deployed in any production app. That context drives the re-rating of PERF-03 and PERF-08 below.

Sources: five reviewer part files in `docs/billing/assessments/parts/` (SEC, PERF, UX, CONF, OLD). Finding IDs are kept so every claim traces back to a part file. Confidence labels: VERIFIED (read in code), HYPOTHESIS (reasoned, not confirmed by running).

## 1. Executive summary

### Assessed state and method

- Assessed SHA: `26e283cb8` on `feature/billing`.
- Four reviewers (security, performance and operability, accessibility/UX/i18n, plan conformance and test adequacy) read the code statically; a fifth reviewer compared the old PR #1581 branch (`39a44e378`) against this one.
- Tool results: brakeman `-w2` reported 0 warnings and 0 errors (194 controllers scanned); bundler-audit reported no vulnerabilities (ruby-advisory-db 2026-11-11). Billing spec baseline (`spec/requests/better_together/billing` plus `spec/services/better_together/billing`): 1192 examples, 6 failures, all agreement-draft specs with one root cause (CONF-11).
- Merge pass: for this report I re-read the cited lines of four High findings (UX-07, UX-17/UX-01, CONF-01, CONF-11's seed code). UX-07, UX-17 (the two checkout address labels) and CONF-01 are confirmed as written. CONF-11's failure is VERIFIED by the CONF reviewer's spec run (not re-run here); its cause is still a HYPOTHESIS (the seed code reads as draft-on-create, so the active state most likely comes from `Seed.import_or_update!` creating the rows first). No High finding was refuted or dropped. PERF-08 was re-rated by instruction, not re-checked.

### Counts after merge

64 merged findings: 4 High, 26 Medium, 32 Low, 2 Info; 0 Critical. (73 raw findings across the four reviewer parts, 9 removed by de-duplication.) The 4 High: CONF-11, CONF-01 with SEC-10, UX-07, UX-17 with UX-01 and UX-02. PERF-08 and PERF-03 were High and Medium in the part, and are re-rated Medium and Low (section 2 notes).

### Readiness verdict

| Gate | Verdict | Reasons |
|---|---|---|
| Merge to main | GO WITH FIXES | Five small fixes first: the six failing seeded-agreement specs and CONF-11 (seeded agreements come out active, so placeholder legal text could sell), the wrong tax report basis select (UX-07), broken label/for pairs on five forms (UX-17, UX-01, UX-02) with an axe spec (UX-22), PDF dates printed in the wrong zone (UX-25), and the decision to squash the localize and Pay-table migrations (PERF-03, PERF-08). All are Effort S to M. Do not merge with red safety specs. |
| First production enablement (host platform only, local methods, billing flag on) | NO-GO at this SHA; GO WITH FIXES after the production package | Needs: the interim host-only fail-closed gate (CONF-01), person and platform scoping on credit grants and walk-up sales (SEC-01, SEC-05), the invoice Upload ownership fix (SEC-06, once confirmed), throttles and PII log filters (SEC-07, CONF-07), concurrency, webhook signature and Pay mount specs (SEC-15 group), operator tooling for dead-lettered events (PERF-09), and the flag-off inertness of the Pay mount (PERF-14). |
| Hosted-platform enablement (any non-host platform sells) | NO-GO | The hosted platform billing agreement, hosted local billing agreement, merchant onboarding and pause mechanism are unbuilt (D3a, D8, D9). Billing must stay off for non-host platforms until the agreement gate exists. |

### Top 10 risks, ranked

1. CONF-11: seeded purchase agreements come out `active`, defeating the safeguard that placeholder legal text can never sell. Six specs are red because of it.
2. CONF-01 / SEC-10: no server-side gate for the hosted billing agreement; any non-host platform steward can enable cash, cheque or e-Transfer and take orders.
3. SEC-05: a walk-up sale can bind an existing user who is not a member of the platform by email, place an order in their name and record agreement acceptance for them.
4. UX-07 and UX-25: tax figures and dates a filer relies on are wrong in the UI (invoice basis unreachable, PDF dates in the wrong zone).
5. SEC-01: store credit can be granted to any Person in the database, not only platform members, and confirms by redirect whether an id exists.
6. SEC-06 (HYPOTHESIS): the buyer owns the invoice and receipt Upload, so the generic Files policy may let them replace the file or make it public.
7. SEC-15 / CONF-04 / CONF-05: no concurrent test for double refund, redeem or pay, no webhook signature or Pay mount test; money-twice and forged-event regressions would not turn the suite red.
8. SEC-07: rate limits are IP only and miss checkout, walk-up sales and refunds; walk-up can mail arbitrary addresses.
9. PERF-14 / PERF-08: billing OFF is not fully inert (Pay mount, cron jobs, tables, migration abort on hosts that already use Pay).
10. CONF-07 / SEC-09 (HYPOTHESIS): buyer name, address and payee settings are not in `filter_parameters` and reach request logs unencrypted.

Next in line: PERF-09 (no operator replay entry point, pending events not re-enqueued, kill switch needs a restart) and UX-17's wider axe gap (UX-22).

### What was NOT assessed

- No browser, axe run or screen reader session; contrast, focus and keyboard findings are partly HYPOTHESIS.
- No EXPLAIN plans, benchmarks or load tests; all index, N+1 and report-cost severities are by reasoning.
- No real concurrency runs; lock-order findings (SEC-03, PERF-06) are HYPOTHESIS.
- No live processor: the Pay extension gem (vendor adapters, Stripe signature verification, callers of `Payments::Succeed`) is not in this tree.
- Other host apps were not read (whether any has Pay tables, PERF-08), and host-app `filter_parameters` were not checked.
- Full list in section 7.

## 2. Cross-referenced findings

### 2.1 Merged findings table

Severity is after merge and after the re-rating of PERF-03 and PERF-08. "Blocks" means: MAIN (merge to main), PROD (first production enablement), HOSTED (hosted-platform enablement), LATER. Where parts disagreed, the higher severity is shown.

| ID(s) | Severity | Confidence | Summary | Where | Blocks |
|---|---|---|---|---|---|
| CONF-11 | High | VERIFIED failure, HYPOTHESIS cause | Six specs fail: seeded agreements are `active`, not `draft`, so placeholder legal text could sell | purchase_agreement_seeds.rb:55-80 | MAIN |
| CONF-01, SEC-10 | High | VERIFIED | No hosted agreement gate; any non-host platform steward can enable local methods and sell | billing/configuration.rb `context_for`, owner_policy.rb:19-22 | PROD (any second platform), HOSTED |
| UX-07 | High | VERIFIED | Tax report "Count a sale by" select lists intervals with missing translations, silently coerces to `paid`; invoice basis unreachable | metrics/billing_reports/new.html.erb:19 | MAIN |
| UX-17, UX-01, UX-02 | High | VERIFIED | 15 labels in 5 forms point at ids that do not exist (checkout address, requirements, tax registration, processor, documents) | checkouts/_billing_address.html.erb:30-37 and four more forms | MAIN |
| SEC-01 | Medium | VERIFIED | Store credit can be granted to any Person, not only platform members | credit_grants_controller.rb:14 | PROD |
| SEC-05 | Medium | VERIFIED | Walk-up sale binds a non-member by email and records agreement acceptance for them | offline_payments/new_buyer.rb, walk_up.rb | PROD |
| SEC-06 | Medium | HYPOTHESIS | Buyer owns the invoice/receipt Upload and may edit it via the generic Files policy | orders/generate_document.rb:47, upload_policy.rb:14 | PROD |
| SEC-07 | Medium | VERIFIED | Rate limits IP only; none for checkout, walk-up, refunds; walk-up can mail arbitrary addresses | config/initializers/rack_attack.rb:114-155 | PROD |
| CONF-07, SEC-09 | Medium | HYPOTHESIS | Buyer name, address, reference and payee settings not in `filter_parameters` | lib/better_together/engine.rb:153 | PROD |
| SEC-15, CONF-04, CONF-05 | Medium | VERIFIED | No concurrency test, no cross-tenant matrix, no Pay mount or webhook signature spec, missing throttle specs | spec/ (see rows in section 3) | PROD |
| PERF-09, SEC-02, OLD batch 1 | Medium | VERIFIED | No operator replay entry; `ReplayEvent` has no caller or authorization; pending events not re-enqueued; kill switch is ENV | replay_event.rb, billing.rake | PROD |
| PERF-14 | Medium | VERIFIED | Billing OFF is mostly inert, but Pay mount, cron entries, tables and `subscribe_all!` still run on every host | engine.rb, routes/billing.rb:27, sidekiq_scheduler.yml | PROD |
| PERF-08 | Medium (was High) | VERIFIED code, HYPOTHESIS host impact | Pay tables migration raises on hosts with Pay tables; `down` drops them. Squash and keep the guard | db/migrate/20261015120000_create_better_together_pay_tables.rb | MAIN (decide) |
| PERF-06, SEC-03 | Medium | HYPOTHESIS | Lock order inverts across refund, cancel and credit-spend paths (deadlock class) | refunds/record.rb:42, orders/cancel.rb:27, add_payment.rb:42 | LATER |
| CONF-02 | Medium | VERIFIED | No pause or suspension mechanism ("pausing must not delete data") | models/billing/*, story doc | HOSTED |
| UX-22 | Medium | VERIFIED | Only three axe specs, none on checkout or steward pages; no ARIA assertions in dom_contracts | spec/features, spec/dom_contracts | MAIN |
| UX-25 | Medium | VERIFIED | PDF placed and paid dates printed without the document time zone | orders/document.rb:43-47,70-72,142 | MAIN |
| UX-13 | Medium | VERIFIED | Money-moving steward actions (mark received, refund, grant credit, reject) have no confirmation | offline_payments/index, sales partials | PROD |
| UX-16 | Medium | VERIFIED | Refunds invisible to the buyer; no refund guidance for processor payments | orders/_details.html.erb:57-75 | LATER |
| UX-18 | Medium | VERIFIED | Plan price entered in minor units while every other money field uses major units | plans/_form.html.erb:181-184 | PROD |
| UX-20 | Medium | VERIFIED | Checkout re-render after an error clears every agreement tick | checkouts/new.html.erb:97-101 | LATER |
| UX-08 | Medium | VERIFIED | Form errors are a banner only; no aria-invalid or error association | plans, tax_registrations, processor_settings, checkout forms | LATER |
| UX-03 | Medium | HYPOTHESIS | Checkout summary refresh is silent to screen readers | checkouts/new.html.erb:13-30 | LATER |
| UX-21 | Medium | HYPOTHESIS | Scroll-to-end agreement lock may trap keyboard and screen reader users | agreement_view_controller.js | PROD |
| UX-26 | Medium | VERIFIED | Most steward pages are reachable only by typing the URL | navigation_builder.rb:642-676 | PROD |
| UX-27 | Medium | VERIFIED | Journey gaps: no buyer cancel, no resend receipt, no tax preview before placing, plan or method change | subscriptions/show, orders/*, routes | LATER |
| PERF-01 | Medium | VERIFIED | Entitlements page re-queries grants per entitlement | entitlements_controller.rb:14,25 | LATER |
| PERF-02 | Medium | HYPOTHESIS | Mobility translations read per row on billing lists | catalog, plans, promotions, subscriptions controllers | LATER |
| PERF-04 | Medium | HYPOTHESIS | Tax report computed synchronously in the request, unbounded span, no throttle | metrics/billing_reports_controller.rb:30 | LATER |
| PERF-05 | Medium | HYPOTHESIS | No orders index covering created_at, paid_at, placed_at | create_better_together_billing_orders.rb:36-68 | LATER |
| PERF-03 | Low (was Medium) | VERIFIED | Localize migration drops populated text columns; squash into create migrations | db/migrate/20261114090000_localize_better_together_billing_text.rb:22-24 | MAIN (decide) |
| SEC-12 | Low | HYPOTHESIS | `Payments::Succeed` never compares charge currency to payment currency | payments/succeed.rb:25-50 | PROD (vendor processors) |
| SEC-04 | Low | VERIFIED | Checkout create has no idempotency token; double submit places two orders | checkouts_controller.rb:35 | LATER |
| SEC-08 | Low | VERIFIED | CSV export leaves authority, collected_by, status, country raw (formula injection) | tax_report/csv.rb:63,77-90 | LATER |
| SEC-11 | Low | VERIFIED | Order agreement acceptance rows are not immutable | order_agreement_acceptance.rb | LATER |
| SEC-13 | Low | HYPOTHESIS | Credit grant has no upper bound; huge amount gives a 500 | credit_grants_controller.rb:28-31 | LATER |
| SEC-14 | Low | HYPOTHESIS | Allowances screen reads quotas without platform filter | allowances_controller.rb:49 | LATER |
| PERF-07 | Low | HYPOTHESIS | PDFs render synchronously and enrol in the buyer's media quota and AV scan | order_documents_controller.rb:49-51 | LATER |
| PERF-10 | Low | HYPOTHESIS | Subscription sweeps scan every local term each run | advance/generate/remind jobs | LATER |
| PERF-11 | Low | HYPOTHESIS | Index hygiene; globally unique processor ids may drop legitimate events across tenants | several migrations | LATER |
| PERF-12 | Low | HYPOTHESIS | Order summary reads translations per line and tax line | orders/summary.rb:28-33 | LATER |
| PERF-13 | Low | VERIFIED | Plan grants panel queries per grant and per role | billing_entitlement_helper.rb | LATER |
| CONF-03, CONF-09 | Low | VERIFIED | Story doc, isolation doc, ERD, lifecycle diagram and roadmap drifted from code | docs/billing/*, docs/diagrams/source | LATER |
| CONF-06 | Low | VERIFIED | Tenant isolation lint guard skips services, mailers and notifiers and permits `find(id)` | billing_tenant_isolation_guard_spec.rb:10-23 | LATER |
| CONF-08 | Low | VERIFIED | Tax rounding tested for one line only | tax/calculator_spec.rb:40-43 | LATER |
| CONF-10 | Low | HYPOTHESIS | Refund and SubscriptionPeriod accept any status change at model level | refund.rb, subscription_period.rb | LATER |
| UX-04 | Low | VERIFIED | Catalog buy links indistinguishable out of context | catalog/_buy_button.html.erb:3 | LATER |
| UX-05 | Low | VERIFIED | Orders list "View" links carry no order context | orders/index.html.erb:35 | LATER |
| UX-06 | Low | VERIFIED | Untaxed lines render an empty cell | _order_summary.html.erb:36-41 | LATER |
| UX-09 | Low | VERIFIED | Required fields unmarked, hints not tied to inputs | credit_accounts, checkouts, plans, walk_up_sales | LATER |
| UX-10 | Low | VERIFIED | Tables lack captions; credit history tables lack column headers | 17 index views | LATER |
| UX-11 | Low | VERIFIED | Hard-coded English `aria-label="breadcrumb"` on seven pages | seven views | LATER |
| UX-12 | Low | VERIFIED | Count strings not pluralized (Ukrainian) | uk.yml:922-923 | LATER |
| UX-14 | Low | VERIFIED | Queue action buttons repeat identical names across rows (mis-action risk with UX-13) | offline_payments/index.html.erb:46-52 | PROD (with UX-13) |
| UX-15 | Low | VERIFIED | Subscription agreement review bypasses the read-to-accept modal | subscriptions/show.html.erb:34-45 | LATER |
| UX-19 | Low | HYPOTHESIS | Orphan labels on locked plan fields; payee fields invite autofill | plans/_form.html.erb, processor_settings/edit | LATER |
| UX-23 | Low | HYPOTHESIS | PDFs carry no language or tag structure | orders/pdf_attachments.rb | LATER |
| UX-24 | Low | VERIFIED | Email summary table `role=presentation`, generic link text, no `lang` | billing_mailer views | LATER |
| UX-28 | Low | HYPOTHESIS | Translated content falls back without a `lang` attribute | catalog, checkout, order views | LATER |
| UX-29 | Low | VERIFIED | Grant summaries show raw identifiers and untranslated words | billing_entitlement_helper.rb:24-37 | LATER |
| UX-30 | Low | VERIFIED | Chart canvases have no text alternative | metrics/reports/_billing_contents.html.erb | LATER |
| UX-31 | Low | VERIFIED | Readiness "not done" glyph is yellow on white | shared/_readiness.html.erb:19 | LATER |
| SEC-16 | Info | VERIFIED | Promotion lockout depends on Rails.cache (null_store silently off) | promotions/redeem.rb | LATER |
| UX-32 | Info | VERIFIED | i18n parity result: 867 billing keys, 0 missing in fr, es, uk (no action) | config/locales | none |

Notes on merges and re-rating:
- CONF-01 and SEC-10 are the same missing hosted-agreement gate. CONF-01 is the more precise statement (the exact bypass in `context_for` and `manage_billing?`) and rated it High; SEC-10 rated Medium. Merged at High.
- PERF-09, SEC-02 and the OLD part's batch 1 describe one gap: no operator replay path. The OLD part confirms nothing in the old branch fixes it (write the rake tasks new).
- SEC-15 with CONF-04 and CONF-05: SEC-15 listed five missing test classes; CONF-04 (concurrency) and CONF-05 (signature and mount) are two of them with more evidence.
- CONF-07 and SEC-09 are the same log-filter gap; CONF-07 added the payee settings keys and rated it Medium. SEC-09 is Low in its part.
- PERF-06 and SEC-03 are the same lock-order inversion seen from two paths (add-payment vs refund, refund vs cancel).
- CONF-03 is a subset of CONF-09 point 4.
- UX-17 generalises UX-01 and UX-02.
- Re-rated for the greenfield context: PERF-03 (localize migration drops columns) Medium to Low; PERF-08 (Pay tables migration) High to Medium. Fix for both: squash into the create migrations and keep the `refuse_foreign_pay_tables!` guard for hosts that already use Pay (also make `down` refuse when rows exist). Their evidence is kept verbatim below. PERF-08 stays Medium rather than Low because a host app that already runs Pay would have its deploy stopped at the migration step; whether any CE host does is unverified.
- Not merged (kept distinct on purpose): SEC-04 (checkout double submit) and UX-27 (journey gaps); SEC-13 and UX-18 (credit amount bounds vs plan price units).

### 2.2 Findings by area (full text from the parts)

Each block below is copied from its part file. Only the severity lines of PERF-03 and PERF-08 are changed, and each carries a re-rating note. IDs in the part files are not renumbered.

#### 2.2.1 Security (SEC)

##### SEC-01 Store credit can be granted to any person in the database, not only platform members
Severity: Medium   Confidence: VERIFIED   Effort: S
Where: app/controllers/better_together/billing/credit_grants_controller.rb:14
What: `holder = BetterTogether::Person.find_by(id: params[:person_id])` is a global lookup; the platform-scoped `find_platform_person` in PersonLookup exists but is not used here.
Evidence: `holder = BetterTogether::Person.find_by(id: params[:person_id])` vs `def find_platform_person(person_id) = platform_people.find_by(id: person_id)` (concerns/billing/person_lookup.rb:25).
Impact: a steward posting any Person UUID creates a credit account and lot on this platform for someone who is not a member, sends them a credit_granted notification (Credit::Grant#record_entry), and confirms by redirect whether that id exists. The people search endpoint is limited to members; this path is not.
Fix: use `find_platform_person(params[:person_id])` (include PersonLookup). Request spec: grant with a non-member person id is refused and creates no account.
Blocks: production enablement

##### SEC-02 ReplayEvent has no authorization and no caller (operator replay path is undefined)
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/services/better_together/billing/replay_event.rb:11
What: the service takes `requested_by:` but authorizes nothing, and `grep -rn ReplayEvent app lib config` finds no caller, so there is neither an unauthorized route nor a usable operator replay path.
Evidence: only references are its own file and a comment in models/billing/event.rb:10.
Impact: a dead-lettered webhook (money event) can only be replayed from a console; whoever builds the UI later may forget the policy check.
Fix: when a caller is added, gate on a policy (manage_billing? plus host-platform operator) and add a request spec for a non-steward being refused.
Blocks: later

##### SEC-03 Lock order inverts between refund (payment then order) and cancel (order then payment)
Severity: Low   Confidence: HYPOTHESIS   Effort: M
Where: app/services/better_together/billing/refunds/record.rb:42 and orders/cancel.rb:27
What: Refunds::Record takes `payment.with_lock` and then Orders::Settle takes `order.with_lock`; Orders::Cancel takes `order.with_lock` and then Release cancels payments (payment lock).
Evidence: record.rb:42 `payment.with_lock do ... settle(refund)` -> settle.rb:18 `order.with_lock`; cancel.rb:27 `order.with_lock do ... Release.call(order)`.
Impact: a seller refund racing a cancel of the same order can deadlock; both paths are wrapped in DeadlockRetry (3 attempts, deadlock_retry.rb) and notifications are after-commit with a dedupe key, so a retry re-runs only DB work. Net effect is a rare 500 rather than a wrong balance. Cancel requires net_paid zero, so the window is narrow.
Fix: document and enforce one order: order, then payment, then credit account. A spec that runs both concurrently (threads, `use_transactional_tests` off) would guard it.
Blocks: later

##### SEC-04 Checkout create has no idempotency token, so a double submit places two orders
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/controllers/better_together/billing/checkouts_controller.rb:35 (place_order)
What: credit grants and seller refunds require a form token used as an idempotency key; buyer checkout does not (`grep -n token checkouts_controller.rb` finds nothing).
Evidence: place_order calls Orders::Place.call with no key; nothing looks for an existing open order for the same plan and buyer.
Impact: a double click or a retry after a slow response creates two orders, each holding the plan's capacity (`reserve!`) until expiry, and two payment rows (two offline claim instructions). No money is taken twice, but limited-capacity plans can be held by a buyer's own duplicate.
Fix: hidden form token stored on the order (unique per platform and buyer) and returned on repeat. Request spec: post the same checkout twice, expect one order.
Blocks: later

##### SEC-05 Walk-up sale can bind an existing user who is not on this platform, by email, and records agreement acceptance for them
Severity: Medium   Confidence: VERIFIED   Effort: S
Where: app/services/better_together/billing/offline_payments/new_buyer.rb:`existing_person`; walk_up.rb:`sell`/`record_in_person_acceptance`
What: when no `buyer_id` is picked, NewBuyer resolves `BetterTogether::User.find_by(email:)` or any EmailAddress globally and returns that Person even if they are not a member of this platform; WalkUp then records the agreements as accepted by that person and places an order in their name.
Evidence: `existing_person` = `BetterTogether::User.find_by(email:)&.person || BetterTogether::EmailAddress.find_by(email:)...` (no platform filter), versus the `buyer_id` path which uses `find_platform_person`. `record_in_person_acceptance` signs with `signer: buyer`, `method: 'seller_assisted'`.
Impact: a steward on a hosted platform types the email of a person who has an account elsewhere; that person now has a billing order, an acceptance of this platform's agreements attributed to them (evidence is only `recorded_by_person_id` in context), and (if payment_received) entitlements, without any action by them. The walk-up also lets the steward probe whether an email belongs to an account (different flow for new vs existing buyer).
Fix: for an existing person who is not an active member, refuse or send an invitation instead of placing the order; never record acceptance for an existing account unless that person is a member and was picked via `buyer_id`. Request spec: walk-up with a non-member's email creates no order and no acceptance.
Blocks: production enablement

##### SEC-06 The buyer owns the invoice and receipt Upload, so the generic Files policy lets them edit it
Severity: Medium   Confidence: HYPOTHESIS   Effort: S
Where: app/services/better_together/billing/orders/generate_document.rb:47 and app/policies/better_together/upload_policy.rb:14
What: invoice and receipt PDFs are stored as `Upload.new(creator: order.buyer, privacy: 'private')`, and `UploadPolicy#update?` is `record.creator == agent`, so the buyer may update (replace the file, change privacy, rename) the billing record through the ordinary uploads UI.
Evidence: generate_document.rb:47 `upload = Upload.new(platform: order.platform, creator: order.buyer, privacy: 'private', ...)`; upload_policy.rb:14-16 `def update? user.present? && record.creator == agent`; steward download is allowed by `stewards_order_document?` (upload_policy.rb:28) which serves whatever file is now attached. Not run: I did not confirm the UploadsController permits `file` and `privacy` (generic ResourceController#resource_params), hence HYPOTHESIS.
Impact: a buyer swaps the invoice PDF for a different file (a forged invoice or receipt the steward then downloads and files for tax), or sets the upload public so the billing address and tax number on the invoice are readable by anyone with the link. The stored `fingerprint` is not re-checked on download.
Fix: deny `update?` and `destroy?` in UploadPolicy when an OrderDocument references the upload (or own the Upload by the platform/system, not the buyer), and verify content checksum against the document at download. Policy spec: buyer cannot update an order-document upload.
Blocks: production enablement

##### SEC-07 Rate limits are IP-only and miss the endpoints that notify third parties or place orders
Severity: Medium   Confidence: VERIFIED   Effort: S
Where: config/initializers/rack_attack.rb:114-155
What: throttles exist for processor_options, claims, order payments, pay, documents, people lookup, credit grants, promotion redemption; none exist for checkout create, walk-up sales create, seller refunds, offline receive/reject/clear/bounce, tax registration and agreement requirement writes, or plan sync. Every throttle is keyed on `req.ip` only.
Evidence: `grep -n "throttle(" rack_attack.rb` in the billing block lists 8 keys (billing/processor_options, offline_claims, order_payments, order_pay, order_documents, people_lookup, credit_grants, promotion_redemptions). Nothing matches `/billing/checkout`, `/billing/walk_up_sales`, `/billing/sales/.../refund`.
Impact: (a) walk-up sales send a CommunityInvitation email to any typed address (NewBuyer, new_buyer.rb:`invite`), so a compromised or malicious steward can mail arbitrary third parties without limit; (b) a signed-in buyer can POST checkout in a loop, each placing an order that reserves plan capacity and notifies the seller (order_placed). Per-IP keys also lump together users behind one NAT and are bypassed by rotating addresses; there is no per-user key (`req.env['warden'].user`).
Fix: add per-IP and per-user throttles for `POST /billing/checkout`, `POST /billing/walk_up_sales`, `/billing/sales/:id/refunds`; add an invitation cap per steward per day in WalkUp. Spec: Rack::Attack spec that the 21st request returns 429.
Blocks: production enablement

##### SEC-08 CSV export does not neutralise formula characters on several user-supplied columns
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/models/better_together/billing/tax_report/csv.rb:63,77-90
What: `safe()` is applied to region, label, processor and number, but `row['authority']` (steward-typed TaxRate authority), `row['collected_by']`, `row['status']` and `row['country_iso']` are written raw; `safe` also omits a leading newline.
Evidence: write_tax: `csv << [safe(row['label']), percent(row['rate']), row['authority'], row['collected_by'], ...]`.
Impact: a TaxRate authority such as `=HYPERLINK(...)` becomes a live formula when a bookkeeper opens the report in a spreadsheet. Author is a steward, so this is a low-trust-boundary issue.
Fix: run every string cell through `safe`. Spec: a rate authority starting with `=` is prefixed in the CSV.
Blocks: later

##### SEC-09 filter_parameters does not cover buyer name or address fields typed at checkout and walk-up
Severity: Low   Confidence: HYPOTHESIS   Effort: S
Where: lib/better_together/engine.rb:153; spec/dummy/config/initializers/filter_parameter_logging.rb:8
What: the engine adds `promotion_code` and OAuth keys; billing params `buyer_name`, `billing_address[line1|line2|postal_code|city_name]` and `reason`/`note` are not filtered. Rails defaults catch `email` (so `buyer_email`) but not these.
Evidence: engine initializer list is `oauth_client_secret oauth_client_secret_digest client_secret authorization promotion_code`. Order address and email are otherwise encrypted at rest (order.rb:69-70), which makes plaintext request logs the weaker link.
Impact: home addresses and names of buyers appear in the request log (and any log shipper) for every checkout and walk-up sale.
Fix: add `buyer_name line1 line2 postal_code city_name state_province_name note seller_reference reference` to the engine filter list. Spec: `Rails.application.config.filter_parameters` includes them.
Blocks: later

##### SEC-10 No server-side gate for the hosted platform billing agreement on non-host platforms
Severity: Medium   Confidence: VERIFIED   Effort: M
Where: app/models/better_together/billing.rb:83-95 (`enabled?`/`compute_enabled?`), app/models/better_together/billing/configuration.rb:63-69 (`context_for`)
What: the decision "every hosted platform must accept the hosted platform billing agreement before any billing" has no code: `enabled?` needs only the host env flag, identity keys and a processor context, and `context_for` returns a local-method context for ANY platform with an enabled ProcessorSetting.
Evidence: `grep -rln "hosted_platform\|merchant_onboarding\|merchant_of_record" app lib config db` finds only comments and adapter capability names (processor_adapter.rb, plan.rb); no model or migration. A steward with `manage_platform` on a non-host platform can enable cash via ProcessorSettings (billing is configurable for them) and sell.
Impact: any hosted platform steward can start taking orders and issuing invoices without an accepted platform agreement or a merchant onboarding. The roadmap marks D2 to D11 as unbuilt, so this is a known gap, but it means the Background rule is not enforced and billing must stay off for non-host platforms until it is.
Fix: add the gate to `compute_enabled?` (an accepted, in-force hosted agreement for the platform, keyed server-side) and to ProcessorSettings update; keep the host exempt. Request spec: non-host platform steward without acceptance gets 404 on every billing route.
Blocks: production enablement (for hosted platforms only)

##### SEC-11 Order agreement acceptance rows are not immutable
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/models/better_together/billing/order_agreement_acceptance.rb
What: the evidence copied onto the order (agreement title, content digest, signer, time) has validations but no `readonly`, no `before_update`/`before_destroy` guard and no DB trigger.
Evidence: `grep -n "readonly\|before_update\|before_destroy" order_agreement_acceptance.rb` returns nothing (only presence and inclusion validations, lines 27-30). Compare CreditLot `attr_readonly :amount_cents, :origin` (credit_lot.rb:21).
Impact: console or a future code path can edit or delete the proof of what a buyer agreed to; there is no tamper signal. Attribution exists (`on_behalf_of`, `acceptance_method`) but not immutability.
Fix: `attr_readonly` on all evidence columns and a `before_destroy { throw :abort }`; model spec for both.
Blocks: later

##### SEC-12 Payments::Succeed accepts an amount from the caller with no currency check
Severity: Low   Confidence: HYPOTHESIS   Effort: S
Where: app/services/better_together/billing/payments/succeed.rb:25-50
What: `success_attributes` writes `amount_cents: amount_cents.presence || payment.amount_cents` from the processor's reported charge; core never compares the charge currency to `payment.currency`.
Evidence: the only inputs are `reference:, amount_cents:, pay_charge:`; `grep -n currency succeed.rb` finds nothing. Amount mismatch is flagged by notification (`payment_amount_mismatch`), but a currency mismatch cannot be seen at all. The vendor adapter (extension gem, not in this tree) is the caller, so it may check.
Impact: a Stripe charge in a different currency with the same minor amount (CAD 45.00 vs JPY 4500 style, or a mis-set session) would mark a payment succeeded and the order paid for the wrong value.
Fix: pass `currency:` through and refuse or flag a mismatch in Succeed; service spec with a mismatched currency.
Blocks: production enablement (vendor processors)

##### SEC-13 Store credit grant and plan amounts have no upper bound
Severity: Low   Confidence: HYPOTHESIS   Effort: S
Where: app/controllers/better_together/billing/credit_grants_controller.rb:28-31; app/services/better_together/billing/currency.rb:22-27
What: `Currency.to_minor` accepts any digit string, and `Credit::Grant` validates only `> 0`; there is no per-grant ceiling and no daily limit per steward.
Evidence: `cents&.positive?` is the only check; DB column is `bigint` (migration credit.rb:60), so a 20-digit amount reaches the database and raises `ActiveModel::RangeError`, which the controller does not rescue (only `Credit::Refused`).
Impact: a steward mistyping or abusing the form gets a 500, or mints a very large spendable balance (a single steward can create unlimited credit worth real goods; the only audit is the lot's `granted_by` and the holder notification).
Fix: cap per grant (config, e.g. 1,000.00) and rescue RangeError as a refusal; two specs (over cap, huge number).
Blocks: later

##### SEC-14 Allowances screen reads quotas by owner and type without a platform filter
Severity: Low   Confidence: HYPOTHESIS   Effort: S
Where: app/controllers/better_together/billing/allowances_controller.rb:49
What: `row_for` does `Quota.find_by(owner:, quota_type: type)` and builds a usage reading for it, while `over_limit_rows` filters `platform_id`; the person-based path is not platform-scoped.
Evidence: Quota uniqueness is `owner_id scope owner_type, quota_type` (quota.rb:33), and people are not tied to one platform (comment at allowances_controller.rb:41).
Impact: a steward can see another platform's usage numbers for a person who holds an entitlement here. Usage counts only, no content.
Fix: filter by `platform_id: billing_owner.id` (or confirm quotas are platform-global by design) and add a cross-platform request spec.
Blocks: later

##### SEC-15 Test gaps: no concurrency, no cross-tenant matrix, no throttle specs for several limits, no Pay mount constraint spec
Severity: Medium   Confidence: VERIFIED   Effort: M
Where: spec/ (searched spec/requests, spec/services, spec/config, spec/initializers)
What: present: event_ingest, webhook_dispatcher, pay_webhook_flow, replay_event, deadlock_retry, credit grant/refund idempotency, throttle specs for order_pay, order_documents, processor_options and credit/people/promotion (spec/config/rack/billing_credit_throttles_spec.rb). Absent: (1) any real concurrent test (`grep -rn "Thread" spec/*/better_together/billing` returns nothing) for double refund, double redeem, pay-vs-expire; (2) a systematic cross-tenant request spec per controller (only ad hoc "other platform" cases, about 40 files mention one); (3) a spec that the `/pay` mount constraint serves only `/webhooks/*` and 404s `GET /pay/payments/:id` (routes/billing.rb:20); (4) throttle specs for offline claims and order_payments (rules exist at rack_attack.rb:123,128); (5) a Stripe-signature rejection spec (Pay's job, but the mount and dispatcher rely on it).
Evidence: `ls spec/requests/better_together/billing` shows throttle specs only for order_pay, order_documents, processor_options.
Impact: the highest-risk behaviours (money twice, wrong tenant) are guarded only by DB constraints and locks that no test would notice regressing.
Fix: add a threaded spec for Refunds::Record, Promotions::Redeem and Credit::Spend (non-transactional example group); a shared example that every billing controller route 404s or 403s for a record of another platform; a routing spec for the Pay mount.
Blocks: production enablement

##### SEC-16 Promotion lockout and code guess protection depend on Rails.cache
Severity: Info   Confidence: VERIFIED   Effort: S
Where: app/services/better_together/billing/promotions/redeem.rb:`count_failure`
What: the 10-failures-per-hour lockout uses `Rails.cache.increment`; with `:null_store` (the dummy test and some hosts) it never counts.
Evidence: spec/dummy/config/environments/test.rb:30 `config.cache_store = :null_store`.
Impact: low, because codes are 16 characters from a 32 symbol alphabet (about 80 bits, promotion.rb:20-21) and the per-IP throttle (rack_attack.rb:153) still applies; but the lockout is silently off on such hosts.
Fix: document the dependency or store the counter in the DB. Not blocking.
Blocks: later


#### 2.2.2 Performance, migrations, host-app impact, operability (PERF)

##### PERF-01 Entitlements page re-queries grants per entitlement, defeating the preload
Severity: Medium   Confidence: VERIFIED   Effort: S
Where: app/controllers/better_together/billing/entitlements_controller.rb:14,25; app/views/better_together/billing/entitlements/index.html.erb:28
What: `includes(..., grants: [])` is preloaded, then both the controller and the view call `entitlement.grants.applied.allowances`, a new scope that issues a fresh query per entitlement (twice), plus `Meter.for` per grant.
Evidence: `entitlement.grants.applied.allowances.map { ... }` (controller:25) and `entitlement.grants.applied.allowances.to_a` (view:28); the page is unbounded (no limit/pagination).
Impact: a person with N entitlements costs about 2N grant queries plus one quota usage lookup per allowance on every page view.
Fix: filter the preloaded array in Ruby (`grants.select { applied? && quota_allowance? }`) once in the controller and pass it to the view; paginate or limit. Spec: query-count assertion on GET /billing/entitlements with 5 entitlements.
Blocks: later

##### PERF-02 Mobility key_value translations are read per row on every billing list (plan, promotion names)
Severity: Medium   Confidence: HYPOTHESIS   Effort: S
Where: catalog_controller.rb:17-20, plans_controller.rb:15-17, promotions_controller.rb:13-16, subscriptions_controller.rb:16, subscribers_controller.rb:19, hubs_controller.rb:15,28, entitlements_controller.rb:14 (views read `plan.name`, `promotion.name`, `entitlement.plan.name`)
What: Plan, Promotion, TaxCategory, LineItem, TaxLine use `translates` on the default key_value backend (config/initializers/mobility.rb:17), which loads translations by a query per record unless `string_translations`/`text_translations` are preloaded. Only Sales and CreditAccounts preload them (`includes(buyer: :string_translations)`).
Evidence: `includes(:plan, ...)` without `:string_translations` in subscriptions/subscribers/hubs/entitlements; `@plans = catalog_plans.order(...)` and `policy_scope(platform_plans).order(:identifier)` with no includes.
Impact: catalog and steward plan list issue 1 to 3 extra queries per plan (name, description, participant_summary, benefits are text vs string tables); promotions list is unbounded and does 1 per promotion. Small plan counts keep it tolerable, a platform with hundreds of promotions does not.
Fix: add `.includes(:string_translations, :text_translations)` (plan) / `:string_translations` (promotion), `plan: [:string_translations, :text_translations]` in term lists; add `.page` to promotions and tax registrations. Spec: query-count guard per index.
Blocks: later

##### PERF-03 Localize migration drops populated text columns with no data carry-over
Severity: Low   Confidence: VERIFIED   Effort: S
Re-rated in this merge (was Medium): billing is greenfield and nothing is deployed. Fix: squash into the original create migrations before first deploy; no carry-over needed. Confirm no staging or review app has run the earlier files. Evidence below is kept as written in the part.
Where: db/migrate/20261114090000_localize_better_together_billing_text.rb:22-24
What: `up` removes name/description/label columns from eight billing tables; `down` re-adds empty columns, so a rollback or any environment that already ran the earlier create migrations loses the text irreversibly.
Evidence: comment "Billing has not been deployed anywhere, so there is nothing to carry over"; `remove_column table, column if column_exists?(table, column)`.
Impact: any staging or review app that ran 20261105..20261113 and holds plans, promotions, tax names, line item descriptions or agreement titles loses them silently on migrate; order line items and acceptance titles are legal/financial records.
Fix: either squash into the original create migrations before first deploy (preferred, since nothing shipped) or copy values into Mobility translation rows in `up` and back in `down`. Spec: migration spec with a seeded row. Confirm no deployed environment has run the earlier files.
Blocks: merge to main (decide: squash) / production enablement

##### PERF-04 Billing report figures are computed synchronously in the web request, unbounded, with no throttle
Severity: Medium   Confidence: HYPOTHESIS   Effort: M
Where: app/controllers/better_together/metrics/billing_reports_controller.rb:30; app/models/better_together/metrics/billing_report.rb:19-36,56-60
What: `create_and_generate!` runs `Billing::TaxReport#call` (about 8 aggregate queries plus in-memory refund allocation) inside the POST, and only the CSV is built by `GenerateBillingReportJob`; the date span is not capped and rack_attack.rb has no throttle for report creation.
Evidence: `report.generate!` -> `self.report_data = build_report_data; save!; GenerateBillingReportJob.perform_later(id)`. `refund_rows` plucks every refund in the span and `order_taxes`/`order_kinds` use `order_id IN (<all refunded orders>)`.
Impact: a steward (or script holding a steward session) requesting a multi-year span on a large platform ties up a web worker; repeated POSTs multiply it. The SQL itself is aggregated (good: no N+1, no period loop), so the cost is bounded by row scans, not query count.
Fix: cap span (for example 5 years), move `build_report_data` into the job (store pending state), chunk the refund order-id list, add a throttle for POST /metrics/billing_reports. Spec: request spec rejecting an over-long span; job spec for generation.
Blocks: later

##### PERF-05 No index on orders for the hot platform+status+date and newest-first queries
Severity: Medium   Confidence: HYPOTHESIS   Effort: S
Where: db/migrate/20261016110000_create_better_together_billing_orders.rb:36-68 (orders indexes); app/controllers/better_together/billing/sales_controller.rb:17; app/models/better_together/billing/order.rb:95-96; app/models/better_together/billing/tax_report.rb:155-160
What: orders have single-column platform_id and buyer_id indexes, (status, expires_at), and no index covering `paid_at`, `placed_at` or `created_at`.
Evidence: no `add_index` mentioning paid_at/placed_at/created_at in any billing migration (grep). Sales list does `platform orders ORDER BY created_at DESC LIMIT 50 OFFSET n`; reports filter `platform_id = ? AND status IN (...) AND paid_at BETWEEN`; buyer pages do `buyer_id = ? ORDER BY created_at DESC`.
Impact: at 10^5 to 10^6 orders per platform, sales index sorts the whole platform set per page, every report scans all platform orders, and deep pages (OFFSET) degrade. Low at launch volume.
Fix: add `(platform_id, created_at DESC)`, `(platform_id, paid_at) WHERE paid_at IS NOT NULL`, `(platform_id, placed_at)`, and `(buyer_id, created_at DESC)`; keep platform_id single index only if another query needs it. Guard with an index-presence schema spec.
Blocks: later

##### PERF-06 Lock ordering differs between order-first and payment-first paths (deadlock class)
Severity: Medium   Confidence: HYPOTHESIS   Effort: M
Where: app/services/better_together/billing/orders/add_payment.rb:42 (order lock, then Credit::PayOrder -> credit/spend.rb:27 account lock); refunds/record.rb:42 (payment lock, then credit/reverse.rb:30 account lock, then Orders::Settle order lock at orders/settle.rb:18)
What: buying with store credit takes order then account; refunding a credit payment takes payment then account then order, an account/order inversion.
Evidence: `order.with_lock do ... take_part` (add_payment.rb:42-48); `payment.with_lock do ... give_back_credit(refund); settle(refund)` (record.rb:42-48). Refunds::Record and Orders::Expire/Cancel wrap `DeadlockRetry.run` (3 attempts) but AddPayment, Credit::Grant, Credit::Spend do not.
Impact: a steward returning a credit part while the buyer concurrently adds another credit part to the same order can deadlock; Postgres aborts one side. Refund side retries, AddPayment side surfaces a 500 to the buyer. Rare, but it is money flow.
Fix: document and enforce one order (order, then payment, then account), or wrap AddPayment in DeadlockRetry and map Deadlocked to a retry message. Spec: two-thread concurrency spec for return-credit vs add-credit-payment.
Blocks: later

##### PERF-07 Invoice/receipt PDFs render synchronously in the request and enrol in the buyer's media quota and AV scan
Severity: Low   Confidence: HYPOTHESIS   Effort: M
Where: app/controllers/better_together/billing/order_documents_controller.rb:49-51; app/services/better_together/billing/orders/generate_document.rb:25-43; app/notifiers/better_together/billing/notifier.rb:60; app/models/concerns/better_together/quotas/attachment_tracking.rb:5-8,43-52; app/models/concerns/better_together/content_security/attachment_hook.rb:17
What: "regenerate in another language" renders up to two PDFs (Prawn plus Factur-X XML/JSON attachments) inline, throttled only at 10/min/IP; every new document creates an `Upload` (creator = buyer) whose attachment is charged to a media_storage quota and enrolled in a malware-scan job.
Evidence: `kinds.each { |kind| Orders::GenerateDocument.call(@order, kind:, locale:) }`; `Upload.new(... creator: order.buyer, privacy: 'private')`; both global attachment hooks include every ActiveStorage attachment.
Impact: slow request under load; each status change (new fingerprint) adds a PDF that is never purged (superseded rows are kept by design, fine for records but unbounded); a buyer near a storage cap could be charged for platform-generated invoices (quota settle failures are only logged, so it does not block, but it skews usage). Unverified whether OwnerResolver charges the buyer or the platform.
Fix: generate in a job and poll or email; resolve quota owner to the platform (or exempt billing documents); add a retention note for superseded blobs. Spec: quota usage after document generation.
Blocks: later

##### PERF-08 Pay tables migration aborts db:migrate on any host that already ran Pay's own migrations, billing on or off
Severity: Medium   Confidence: VERIFIED (code); HYPOTHESIS (whether any host app is affected)   Effort: M
Re-rated in this merge (was High): billing is greenfield. Fix: squash into the create migrations, keep the guard for hosts that already use Pay, and make `down` refuse when rows exist; check each CE host app schema for pay_* tables. Evidence below is kept as written in the part.
Where: db/migrate/20261015120000_create_better_together_pay_tables.rb:38-55 (`refuse_foreign_pay_tables!`)
What: the engine's migration raises `ForeignPayTablesError` if pay_customers/pay_subscriptions/etc. exist without platform_id; engine migrations are appended to every host, so a host with its own Pay install cannot finish `db:migrate` after upgrading CE, even with BT_BILLING_ENABLED unset.
Evidence: `raise ForeignPayTablesError, "... already exist without platform_id (created by Pay's own migrations)..."`; `down` is `drop_table ... force: :cascade` on all six Pay tables.
Impact: a gem bump on such a host stops its deploy at the migration step (and the failing migration blocks every later CE migration). Rolling back drops Pay data wholesale. Also `Pay.setup` (config/initializers/pay.rb) globally sets `model_parent_class` and `send_emails = false`, and billing_pay_extensions.rb forces platform scoping, encryption and `queue_as :billing` onto Pay models and jobs for any host Pay usage.
Fix: gate the Pay tables and Pay initializers on a flag the host opts into, or provide a documented upgrade path; make `down` refuse when rows exist. Before release, check each CE host app's schema for pay_* tables (this review did not read other repos). Spec: migration spec against a schema with Pay's stock tables.
Blocks: merge to main (decide) / production enablement

##### PERF-09 Operator tooling is thin: no replay entry point for Billing::Event, kill switch is env plus restart, stuck pending events are not re-enqueued
Severity: Medium   Confidence: VERIFIED   Effort: M
Where: lib/tasks/better_together/billing.rake:7,19 (only Pay::Webhook list/reprocess); app/services/better_together/billing/replay_event.rb (referenced by nothing but docs/specs); app/models/better_together/billing/event.rb:76-82,130-133; app/models/better_together/billing/configuration.rb:21-23
What: dead-lettered `Billing::Event` rows can be replayed only from a Rails console calling `ReplayEvent`; the sweep dead-letters `pending` events older than 6h without re-enqueueing them; the only kill switch is BT_BILLING_ENABLED (read from ENV, needs a process restart).
Evidence: grep for `ReplayEvent` in app/ lib/ config/ returns only the service; rake file defines `pay_webhooks` and `reprocess_pay_webhook` only. Orphaned payment path records a pending refund and a notification (payments/succeed.rb:82-85) but no operator listing or rake task for orphaned payments was found.
Impact: during a processor outage or a lost Sidekiq job an operator has a notification and nothing to act with except console access; pausing billing quickly (for example after a processor incident) means a rolling restart. A pending event whose enqueue was lost waits 6h, is dead-lettered, then needs manual replay.
Fix: add `better_together:billing:replay_event[ID]`, `list_events[status]` and `orphaned_payments` rake tasks (reuse the services), an `enqueue_pending` step in the sweep, and document the pause path (platform-level pause that keeps data, per the roadmap) in docs/production/billing_queue_rollout.md. Spec: rake task specs.
Blocks: production enablement

##### PERF-10 Subscription sweeps scan every local term each run, with 2 to 6 queries per term
Severity: Low   Confidence: HYPOTHESIS   Effort: S
Where: app/jobs/better_together/billing/{advance_subscriptions,generate_renewals,remind_renewals}_job.rb:perform; config/sidekiq_scheduler.yml:117-130
What: each job iterates `SubscriptionTerm.local.select(:id).find_each` and re-fetches each term, instead of selecting only terms whose period end, grace end or reminder window falls in range; AdvanceSubscriptions runs hourly.
Evidence: `SubscriptionTerm.local.select(:id).find_each { |row| advance(row.id) }`; Advance/Renew take `term.with_lock` per term.
Impact: with 10^4 local subscriptions the hourly job takes 10^4 row locks and about 5x10^4 queries every hour even when nothing is due; it all runs on the billing queue that payment webhooks share (a long sweep delays webhook processing unless the capsule has spare concurrency). Per-term errors are rescued and reported (good), so it is slowness, not data risk.
Fix: pre-filter by due date (join pay_subscriptions where current_period_end <= now or grace_ends_at <= now) and index `pay_subscriptions(status, current_period_end)`; consider a separate low-priority queue for sweeps. Spec: job spec asserting untouched terms are not locked.
Blocks: later

##### PERF-11 Index hygiene: redundant platform_id indexes, low-cardinality single-column indexes, missing Pay subscription status/period index, globally unique processor ids
Severity: Low   Confidence: HYPOTHESIS   Effort: S
Where: db/migrate/20261016110000_create_better_together_billing_orders.rb:36,123; db/migrate/20261015130000_create_better_together_billing_events.rb:73-77; db/migrate/20261015120000_create_better_together_pay_tables.rb:83,148-151; db/migrate/20261105100000_create_better_together_billing_credit.rb:74-75
What: (a) every table has `platform_id` and `(id, platform_id)` unique indexes, and several also have composites led by platform_id, so the single index is redundant write cost; (b) events and payments carry single indexes on `processing_status`, `outcome_kind`, `status` (few distinct values); (c) pay_subscriptions indexes `metered` and no `(status, current_period_end)`; (d) credit lots have both `(credit_account_id, expires_at)` and partial `expires_at WHERE remaining_cents > 0`; (e) `pay_customers (processor, processor_id)` and `billing_events (processor, event_id)` are unique across platforms.
Impact: (a),(b),(d) are extra write amplification on hot payment tables, small. (c) renewals and subscriber filters scan. (e) is correct for Stripe-style random ids, but an adapter with short or per-account sequential ids (or a test processor) used by two platforms would hit a unique violation across tenants, which for events means a legitimate event is dropped as a duplicate.
Fix: drop redundant singles after adding composites; make (e) unique on `(platform_id, processor, event_id)` plus a non-unique `(processor, event_id)` if global lookup is needed, or document that adapters must return globally unique ids. Spec: ingest spec with the same event_id on two platforms.
Blocks: later

##### PERF-12 Order summary, email and PDF read translated text per line and per tax line; checkout writes a translation row per locale
Severity: Low   Confidence: HYPOTHESIS   Effort: S
Where: app/services/better_together/billing/orders/summary.rb:28-33; app/services/better_together/billing/orders/generate_document.rb:41-47; app/services/better_together/billing/orders/apply_tax.rb:37-40
What: `Summary.for_order` calls `order.line_items.map`, then `line.description` and `line.tax_lines.to_a` per line (translation query plus tax line query each), and tax line `label` per row; `document.summary` is built again for the fingerprint, and each tax line snapshots its label in every available locale at checkout.
Evidence: `items = order.line_items.map { |line| Item.new(description: line.description, ..., tax_lines: line.tax_lines.to_a) }`; `snapshot_translations(:label)`.
Impact: an order with 3 lines and 2 taxes costs roughly 15 to 25 small queries per render of show, email and PDF, and 4 locales x (lines + tax lines) translation inserts at checkout. Acceptable at small order sizes, but this one object feeds three surfaces so it is the cheapest place to fix.
Fix: `order.line_items.includes(:string_translations, tax_lines: :string_translations)` in `for_order`; memoize summary per order in `Document`. Spec: query-count guard on `Summary.for_order`.
Blocks: later

##### PERF-13 Plan grants panel issues a query per grant and per role while rendering
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/helpers/better_together/billing_entitlement_helper.rb:15-18,47-57; app/views/better_together/billing/plans/_grants.html.erb:10,30-33
What: `billing_grant_place` does `Community.find_by` per grant; `billing_grantable_roles` runs `role.resource_permissions.pluck` per role, twice (platform and community), and the community select loads up to 200 communities with translated names on every plan page view.
Evidence: `role.resource_permissions.pluck(:identifier).any? { ... }` inside `reject`; `BetterTogether::Community.find_by(id: parameters['community_id'])`.
Impact: steward-only page; N is small. Still a free fix and the community select can be heavy on a platform with many communities.
Fix: preload `resource_permissions` and grants' communities in one query; cache the privileged-role set per request. Spec: query-count on plans#show.
Blocks: later

##### PERF-14 Billing OFF is mostly inert, with four exceptions that touch every host
Severity: Medium   Confidence: VERIFIED   Effort: M
Where: lib/better_together/engine.rb:36,234-235; config/initializers/pay.rb; config/initializers/billing_pay_extensions.rb; config/sidekiq_scheduler.yml:53-130; db/migrate/20261015120000..20261117100000; config/routes/billing.rb:27-29
What: with BT_BILLING_ENABLED unset the controllers 404 (OwnerScoped), navigation links hide, `Billing.enabled?` short-circuits on an ENV check, and failures log nothing. But: (1) `require 'pay'` and a hard `pay ~> 12.4` dependency load for every host (gemspec:65); (2) all billing and Pay migrations run on every host (dozens of new tables, see PERF-08 for the abort case); (3) 11 billing cron entries run every hour or day against empty tables,; the redaction job uses Sidekiq Redis directly for its lock; (4) `Pay::Engine` is mounted at /pay for webhooks whenever any Pay processor gem is installed, regardless of the flag, and `WebhookSubscriptions.subscribe_all!` runs unconditionally.
Evidence: `if [Pay::Stripe, ...].any?(&:enabled?) mount Pay::Engine ...` (routes/billing.rb:27); sidekiq_scheduler.yml has no flag condition; `register_builtin_processors!` and `subscribe_all!` in `config.after_initialize`.
Impact: a host that never enables billing still carries the tables, the cron jobs (cheap: indexed empty scans) and a public unauthenticated webhook path that depends on Pay's signature check alone. Boot cost is small (adapter registration, notification subscribers). With a Stripe gem present and billing off, a correctly signed event would be attributed to the host platform because `context_for` does not check the flag for non-local processors (configuration.rb:57-63); signature secret absence makes this unlikely.
Fix: wrap the Pay mount and `subscribe_all!` in `Billing::Configuration.requested?`; make scheduled jobs return early when `requested?` is false; document the always-on tables. Spec: routing spec that /pay/webhooks 404s with the flag off.
Blocks: production enablement


#### 2.2.3 Accessibility, UX and i18n (UX)

##### UX-01 Billing address labels do not point at their inputs
Severity: Medium   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing/checkouts/_billing_address.html.erb:30-37
What: `address_form.label :line1` / `:postal_code` generate `for="billing_address_line1"` and `for="billing_address_postal_code"`, but the inputs are given custom ids `billing-checkout-address-line1` and `billing-checkout-address-postal-code`.
Evidence: `address_form.label :line1, ...` next to `address_form.text_field :line1, ..., id: 'billing-checkout-address-line1'`. Rails label derives `for` from object name and method, not from the field's custom id.
Impact: Screen reader users hear an unlabelled edit field for street and postal code on the checkout, and clicking the label does not focus the field. This is the page where tax is decided.
Fix: pass `for: 'billing-checkout-address-line1'` to the labels (or drop the custom ids). Guard: a dom_contract or axe spec asserting every `label[for]` resolves to an element.
Blocks: merge to main

##### UX-02 Document language select label does not match its select id
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing/orders/_documents.html.erb:21-23
What: `form.label :document_locale` yields `for="document_locale"` while the select has `id: dom_id(order, :document_locale)`.
Evidence: `form.select :document_locale, ..., id: dom_id(order, :document_locale)`.
Impact: The "Document language" select is unnamed for assistive tech on order and sale pages.
Fix: `for: dom_id(order, :document_locale)` on the label. Guard: same label-for resolution spec as UX-01.
Blocks: later

##### UX-03 Checkout summary refresh is silent to screen readers
Severity: Medium   Confidence: HYPOTHESIS   Effort: S
Where: app/views/better_together/billing/checkouts/new.html.erb:13-30; app/javascript/controllers/better_together/billing_checkout_address_controller.js:12-19
What: Choosing another billing address swaps the tax summary inside `<turbo-frame id="billing-checkout-tax-frame">` by setting `frame.src`; the frame has no `aria-live`/`role=status`, and focus stays on the select.
Evidence: controller `refresh` only sets `frame.src`; the frame element carries no aria attributes.
Impact: A blind buyer changes the address and never learns the tax and total changed before placing the order. Also no busy state or error handling if the frame request fails (a Turbo "Content missing" is shown in the frame, unannounced).
Fix: wrap the summary in `aria-live="polite" aria-atomic="true"` (set `aria-busy` while loading), add a visually hidden status "Tax updated". Guard: dom_contract for the live attribute.
Blocks: later

##### UX-04 Catalog "Buy / Subscribe" links are indistinguishable out of context
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing/catalog/_buy_button.html.erb:3; catalog/index.html.erb:17-23
What: Every plan card repeats the same link text ("Subscribe", "Buy", "Get free") with no plan name in the accessible name.
Evidence: `link_to t("better_together.billing.catalog.#{label}"), new_billing_checkout_path(...)` with no `aria-label` or hidden plan name.
Impact: A links list in a screen reader shows N identical "Subscribe" links; WCAG 2.4.4 / 2.5.3 not met.
Fix: append `<span class="visually-hidden"> plan.name</span>` (and i18n `aria-label` with `%{plan}`). Guard: dom_contract.
Blocks: later

##### UX-05 Orders list "View" links carry no order context
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing/orders/index.html.erb:35
What: Each row has a link named only "View" (`globals.view`).
Evidence: `link_to t('globals.view'), billing_order_path(order, ...)`.
Impact: Same as UX-04 for order rows (the order number is in the row header but not in the link name).
Fix: add visually hidden order number inside the link.
Blocks: later

##### UX-06 Taxed marking is by presence only; untaxed lines are an empty cell
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing/_order_summary.html.erb:36-41
What: Only a taxed line shows a "Taxed" badge; a line without tax renders an empty `<td>`, with a comment saying this is deliberate.
Evidence: `<% if line.taxed %><span class="badge ...">Taxed</span><% end %>`.
Impact: Screen reader users hear an empty cell in a column headed "Tax"; mixed taxed/not-taxed orders have no "Not taxed" statement (the brief lists Taxed/Not taxed marking as a check). The email and PDF need to be compared (see later findings).
Fix: render a visually hidden "Not taxed" in the empty cell. Guard: summary surface spec.
Blocks: later

##### UX-07 Tax report "Count a sale by" select lists the wrong options with missing translations
Severity: High   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/metrics/billing_reports/new.html.erb:19; config/locales/en.yml:3566-3568; app/models/better_together/billing/tax_report.rb:31,109
What: The basis select iterates `TaxReport::INTERVALS` (month, quarter, year) and translates them under `...additional.basiss.<i>`, a key that does not exist. The real options are `BASES = %w[paid invoice]` with labels under `...additional.bases`.
Evidence: view line 19 `INTERVALS.map { |i| [t("...additional.basiss.#{i}"), i] }`; en.yml has `bases: {invoice, paid}` and no `basiss`; key-existence script found 0 keys under `basiss`; model line 109 `BASES.include?(basis.to_s) ? basis.to_s : 'paid'`.
Impact: The report form shows three "translation missing" options. Any choice (month/quarter/year) is silently coerced to `paid`, so the by-placed-date (`invoice`) basis is unreachable from the UI and a tax filer cannot count sales by invoice date. The dom_contract only asserts the id and label[for], so it passes.
Fix: iterate `TaxReport::BASES` and use `...additional.bases.#{i}`; add an assertion in `spec/dom_contracts/billing_tax_reports_spec.rb` that the basis select offers exactly `paid` and `invoice` with non-"translation missing" text.
Blocks: merge to main

##### UX-08 Form errors are a summary banner only; fields carry no aria-invalid or error association
Severity: Medium   Confidence: VERIFIED   Effort: M
Where: app/views/better_together/billing/plans/_form.html.erb:14-20; tax_registrations/_form.html.erb:8-13; processor_settings/edit.html.erb:24-28; agreement_requirements/index.html.erb:57-60; promotions/new.html.erb:9; checkouts/new.html.erb:8-10
What: Every billing form shows `role="alert"` with `full_messages` (or one error string) but no field gets `aria-invalid="true"` or `aria-describedby` pointing at its message, and the banner does not link to the fields. Checkout error is one generic code (`error_<code>`), not tied to the control at fault.
Evidence: grep for `aria-invalid` in app/views/better_together/billing finds none on inputs; `aria-describedby` appears only in 4 files for hints (agreements summary, a few form hints).
Impact: Keyboard and screen reader users get the alert read but must hunt for the field; focus is not moved to the summary after a failed submit (a full re-render, so focus returns to the document top).
Fix: add `tabindex="-1"` plus autofocus on the error summary, `aria-invalid` and `aria-describedby` on fields with errors, links from the summary. Guard: dom_contract for one form with an error.
Blocks: later

##### UX-09 Required fields are not marked, and most hints are not tied to their inputs
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing/credit_accounts/index.html.erb:42-58; checkouts/_billing_address.html.erb:28-39; plans/_form.html.erb; walk_up_sales/new.html.erb
What: Fields that are `required: true` (credit amount, promotion code, report dates) show no visible required indicator and no `aria-required`; billing address fields have no `required` at all though tax needs country and state (the checkout falls back to "tax is worked out once it is entered"). `.form-text` hints (grant_expires_hint, lookup_hint, code_hint, renew_with_hint) sit beside inputs without `aria-describedby`.
Evidence: `text_field_tag :amount, ..., required: true` with label text lacking a marker; `<div class="form-text">` siblings with no id referenced.
Impact: A screen reader user does not hear the format hints (for example "leave blank for credit that never expires"), and sighted users cannot tell required fields until a browser bubble appears.
Fix: shared helper emitting `(required)` text and `aria-describedby` for hints; address country/state `required` when the plan is taxed.
Blocks: later

##### UX-10 Tables have no captions; credit history tables have no column headers
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing/{orders,sales,subscribers,subscriptions,plans,promotions,tax_registrations,processor_settings,agreement_requirements,offline_payments,allowances,credit_accounts}/index.html.erb; credits/show.html.erb:63-77; credit_accounts/show.html.erb:44-58
What: Of 19 tables across 17 files, only those in credits/show, credit_accounts/show, subscriptions/show and subscribers/show have a `<caption>`; the `credits` history tables have a caption but only `<td>` cells with no `<thead>`, so date, kind, amount, actor and note columns have no header.
Evidence: table and caption count per file via grep; history `<tbody>` rows are all `<td>`.
Impact: Screen reader table navigation announces no column names for the ledger, which is the most money-relevant table for a buyer. Missing captions are a minor navigation aid.
Fix: add `<thead>` with visually hidden or visible headers to the history tables and visually hidden captions elsewhere.
Blocks: later

##### UX-11 Hard-coded English `aria-label="breadcrumb"` on seven steward pages
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing/{offline_payments/index,plans/new,plans/edit,processor_settings/edit,tax_registrations/new,tax_registrations/edit,walk_up_sales/new}.html.erb:6-9
What: `<nav aria-label="breadcrumb">` is a literal English string in every locale.
Evidence: grep `aria-label="breadcrumb"`.
Impact: French, Spanish and Ukrainian screen reader users hear an English landmark name. Rest of the billing views are fully translated.
Fix: use an existing or new `t('globals.breadcrumb')` key (add to all four locales); the i18n parity script in this area shows it is easy to keep in step.
Blocks: later

##### UX-12 Ukrainian (and French/Spanish) count strings are not pluralized
Severity: Low   Confidence: VERIFIED   Effort: S
Where: config/locales/uk.yml:922-923 (every_n_months, every_n_years); config/locales/en.yml:1079 (hub access_count)
What: "every %{count} months" is a single string in every locale; the only billing key with plural forms is `metrics.reports.billing.authorities.other` (not a plural group at all). Ukrainian uses abbreviations ("кожні %{count} міс.") to avoid inflection.
Evidence: plural-group scan found no `one/few/many/other` group for billing keys in any locale.
Impact: Mostly acceptable because of the abbreviation trick, but "кожні 1 міс." is avoided only because count==1 branches to `month`; any new count text will read wrongly in uk (which needs one, few, many, other).
Fix: if more counted text is added, use `count:` with plural subkeys; keep the abbreviation workaround documented.
Blocks: later

##### UX-13 Money-moving steward actions have no confirmation (mark received, record refund, credit refund, grant credit, reject)
Severity: Medium   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing/offline_payments/index.html.erb:46-50; sales/_offline_payment.html.erb:40-43,49-51,87; sales/_credit_payments.html.erb (submit); credit_accounts/index.html.erb:57
What: Only bounce, cancel, waive, cancel-now, deactivate plan and remove grant use `turbo_confirm`. "Mark received" (settles an order and grants access), "Record refund", "Refund to credit", "Grant credit" and "Reject" submit immediately.
Evidence: grep `turbo_confirm` over views lists 8 uses, none on these.
Impact: One mis-click in the queue marks a cash order paid and entitles the buyer; one typo in the refund amount field records money handed back (there is no undo). The queue button is also reached from a dense table of identical "Mark received" buttons.
Fix: confirm with amount and buyer in the message for refund, mark-received (queue) and grant credit; add an undo path or at least an audit line visible on the order. Guard: request spec plus dom_contract for `data-turbo-confirm`.
Blocks: later

##### UX-14 Queue action buttons repeat identical names across rows
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing/offline_payments/index.html.erb:46-52
What: Each row has a "Mark received" button and a "View" link with no order number or buyer in the accessible name.
Evidence: `button_to t(...mark_received), receive_billing_offline_payment_path(...)`; no visually hidden context.
Impact: A screen reader user (or voice control user saying "click mark received") cannot tell which order a button affects, on a button that records money. Combined with UX-13 it is a real mis-action risk.
Fix: add visually hidden order number to the button text (`aria-label` with `%{number}`).
Blocks: later

##### UX-15 Subscription agreement review bypasses the read-to-accept modal and the label has no "I accept" text
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing/subscriptions/show.html.erb:34-45
What: Missing agreements on a subscription are accepted with a plain checkbox whose label is only a link to the agreement (`target="_blank"`), unlike checkout which uses the shared modal with the scroll-to-end lock and "I accept <title>" text.
Evidence: `label_tag ... do link_to agreement.title, agreement_path(...), target: '_blank', rel: 'noopener' end`.
Impact: Inconsistent consent experience on the one gate that blocks renewal; a screen reader hears the checkbox named only by the agreement title with "link"; opening in a new tab is not announced; clicking the label text opens the link instead of toggling the box.
Fix: reuse the checkout markup (view button plus "I accept" label); mention new tab if kept.
Blocks: later

##### UX-16 Refunds are invisible to the buyer and processor payments give the steward no refund guidance
Severity: Medium   Confidence: VERIFIED   Effort: M
Where: app/views/better_together/billing/orders/_details.html.erb:57-75; sales/_offline_payment.html.erb:61-70; sale_refunds_controller.rb:41-45
What: The payments table lists method, status and amount only; no refund rows, no refunded amount, no remaining balance for the buyer. The steward's refund form exists only under offline and credit payments; a card payment gets no refund card, and nothing says "refund this at your processor".
Evidence: grep `refund` in views returns only sales/_credit_payments, sales/_offline_payment and a processor setting hint. Story doc 4.9 marks this "P (Refund rows exist; request state does not)".
Impact: A buyer refunded 50 CAD sees only the original payment and total and sends support mail; a steward refunding a card order from the sale page finds no control. The recorded refund and its tax portion are also not shown on the PDF/email summary (not checked beyond Summary usage).
Fix: add a Refunds section to the shared `_details` with date, amount, tax part and reason; add a hint card for processor payments pointing to the vendor dashboard.
Blocks: later

##### UX-17 Systematic label/for mismatch: 15 labels in 5 forms point at ids that do not exist (generalizes UX-01 and UX-02)
Severity: High   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing/agreement_requirements/index.html.erb:64-84 (5); tax_registrations/_form.html.erb:25-54 (5); processor_settings/edit.html.erb:62,71 (2); checkouts/_billing_address.html.erb:30,34 (2); orders/_documents.html.erb:20 (1)
What: These forms call `form.label :field` (which emits `for="<object>_<field>"`) while the matching input is given a hand-written `id: 'billing-...'`, so the label points nowhere.
Evidence: for example `form.label :mode, ...` then `form.select :mode, ..., id: 'billing-requirement-mode'`; `form.label :effective_from` then `form.date_field ..., id: 'billing-tax-registration-from'`; `form.label :hold_hours` then `number_field ..., id: 'billing-processor-hold-hours'`. A grep of every `form.label` without `for:` in app/views/better_together/billing listed these 15; explicit-`for:` labels elsewhere (walk-up, credit, offline, orders, plans renewal) are fine.
Impact: On the agreement requirement form (a billing gate), the tax registration form (registration numbers and effective dates, which print on invoices) and the processor form, screen reader users hear unlabelled combo boxes and date fields, voice control users cannot say "click Agreement", and clicking labels does nothing. WCAG 1.3.1, 3.3.2, 4.1.2.
Fix: pass `for:` matching each custom id (or drop the custom id where specs do not need it). Guard: one shared dom_contract that walks each billing page and asserts every `label[for]` resolves to an element and every visible input has a label (the existing `billing_tax_reports_spec` does this for the report form only).
Blocks: merge to main

##### UX-18 Plan price is entered in minor units while every other money field uses decimal major units
Severity: Medium   Confidence: VERIFIED   Effort: M
Where: app/views/better_together/billing/plans/_form.html.erb:181-184; config/locales/en.yml:1538-1539
What: The plan form asks for "Amount (smallest currency unit)" as an integer (`4500 = 45.00`), while checkout parts, credit grants, add-payment and refund amounts all take and show decimal major units.
Evidence: `form.number_field :amount_cents, min: 0, required: true`; hint "e.g. 4500 = 45.00 for most currencies; 4500 = 4500".
Impact: A steward typing `45` publishes a 0.45 plan, or `45.00` is rejected by the integer field; a price off by a factor of 100 goes live on the public catalog (no preview of the resulting price before saving). For a processor-linked plan it is locked after creation, so the mistake needs a new price.
Fix: accept major units with the shared `Currency.to_minor`, show a live formatted preview, keep the hint for zero-decimal currencies. Guard: plan request spec with "45.00" and "45".
Blocks: later

##### UX-19 Locked plan fields leave orphan labels; processor instruction fields invite browser autofill
Severity: Low   Confidence: HYPOTHESIS   Effort: S
Where: app/views/better_together/billing/plans/_form.html.erb:52-53,63-65; plans/_locked_value.html.erb:2-3; processor_settings/edit.html.erb:38-46
What: When a field is locked, `form.label :name` / `:description` is rendered and no input follows (an orphan label for a missing control), and the visible name is a `<span class="form-label">` not tied to the value. Payee instruction fields (email, phone) are plain text/email inputs without `autocomplete="off"`, so a browser may fill the steward's own email or phone into the payee instructions.
Evidence: `_locked_value` renders `<span class="form-label d-block fw-bold"><%= label %></span>` then a `div.form-control-plaintext`; instruction fields set only `type` and `required`.
Impact: Redundant label noise for assistive tech; a steward who saves without noticing could publish their personal email as the e-transfer address shown to buyers.
Fix: render locked values as `<dl>` or `aria-labelledby`, and add `autocomplete: 'off'` to instruction fields.
Blocks: later

##### UX-20 Checkout re-render after an error clears every agreement tick
Severity: Medium   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing/checkouts/new.html.erb:97-101; app/controllers/better_together/billing/checkouts_controller.rb:150-154
What: `render_again` re-renders `new` with status 422, but each agreement checkbox is hard-coded `check_box_tag ..., '1', false` and is locked again until the buyer re-opens the modal and scrolls to the end.
Evidence: `check_box_tag agreement_acceptance_param_name(agreement), '1', false, ... aria: { disabled: 'true' }`.
Impact: A buyer who forgets to pick a state (address error) or hits a refused order must re-read every agreement in the scroll-gated modal; on a platform with 3 agreements that is the likeliest abandonment point. Parts amounts and typed address are preserved, so the agreement lock is the odd one out.
Fix: render checked (and unlocked) for ones accepted in the failed POST; the server still re-verifies. Guard: request spec posting without a state and asserting the boxes are checked.
Blocks: later

##### UX-21 Scroll-to-end agreement lock and focus handling: unverified for keyboard and screen reader users
Severity: Medium   Confidence: HYPOTHESIS   Effort: M
Where: app/javascript/controllers/better_together/agreement_view_controller.js:20-30,195-225; app/views/better_together/billing/checkouts/new.html.erb:97-101
What: The tick box is `required` but blocked by capture-phase click and keydown handlers until a scroll event proves the buyer reached the end; on completion the script calls `checkbox.focus()` while the Bootstrap modal may still be open.
Evidence: `document.addEventListener('click', this._preventToggleClick, true)`, `checkbox.focus()`; the box carries `aria-disabled="true"` but is not `disabled`, so it is focusable and announced as a normal checkbox that silently does nothing; the viewer link is `role="button"` on an `<a>` (Space does not activate it).
Impact: A keyboard or screen reader user may never fire the scroll condition (short agreement, reader that does not scroll the container) and cannot tick the box, so cannot buy; or focus is pulled behind the modal. Without JS the box works (graceful) so the gate is JS-only. I did not run it, so rated HYPOTHESIS.
Fix: also unlock when the modal content is fully visible without scroll or after Accept in the modal; use a real button for "View agreement"; announce lock reason via `aria-describedby`. Guard: a feature spec with `:accessibility` that ticks via keyboard only.
Blocks: later

##### UX-22 Accessibility test coverage is narrow: three axe specs, all on lookup widgets; no ARIA assertions in billing dom_contracts
Severity: Medium   Confidence: VERIFIED   Effort: M
Where: spec/features/better_together/billing/{plan_form_lookups,credit_person_lookup,walk_up_buyer_lookup}_spec.rb; spec/dom_contracts/billing_*.rb (19 files)
What: `be_axe_clean` runs only on the plan form (whole page), the credit lookup form and the walk-up form. The 19 billing dom_contract specs and `order_summary_surfaces_spec` assert ids and text, with zero `aria`/`role` occurrences and (apart from the report form) no `label[for]` resolution checks. docs_screenshots specs capture images only.
Evidence: grep for `axe|be_axe_clean` over spec returns those three features; `grep -c "aria\|role="` over the dom_contracts is 0 for every billing file.
Impact: UX-01, UX-02 and UX-17 (15 broken labels on checkout, requirements, tax registration and processor forms) would be caught by one axe run; they shipped because none of those pages is scanned. Checkout, orders, sales, subscriptions, credit and entitlements pages are never scanned for contrast, headings or landmarks either.
Fix: add one `:accessibility, :js` feature spec that visits each billing page (buyer and steward) and calls `be_axe_clean`; fold a `label[for]` resolver into the dom_contract helper.
Blocks: merge to main

##### UX-23 Receipts and invoices PDFs carry no language or tag structure
Severity: Low   Confidence: HYPOTHESIS   Effort: M
Where: app/services/better_together/billing/orders/pdf_attachments.rb:28,73; orders/document.rb:50-51,105-107; spec/services/better_together/billing/orders/document_spec.rb:105-107
What: The PDF writer adds XMP metadata and attachments, but no `/Lang`, `/MarkInfo` or structure tree; document text is drawn with Prawn tables, so it is untagged. The Ukrainian "Cyrillic included" spec only asserts the output starts with `%PDF`.
Evidence: grep for `Lang|MarkInfo|StructTreeRoot|DisplayDocTitle` in pdf_attachments.rb returns nothing. The receipts gem was not installed on this host, so font coverage was not inspected.
Impact: Screen readers cannot read invoices reliably, and PDF/UA is not met; unproven whether uk glyphs render (spec checks only the header). Invoices are the legal tax document, so this matters for blind accountants and for accessibility law where the platform operates.
Fix: set `/Lang` and `/Info /Title` display flag in the catalog; add a spec that extracts text from the uk PDF (pdf-reader) and asserts Cyrillic characters round-trip; consider offering the HTML page as the accessible equivalent (the order page already shows the same Summary).
Blocks: later

##### UX-24 Email: data table marked role=presentation, generic link text, no language attribute
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing_mailer/_order_summary.html.erb:7; notification.html.erb:11-14; app/views/layouts/better_together/mailer.html.erb:2
What: The summary table has `role="presentation"` yet uses `<th>` header cells and holds tabular figures; the CTA link reads only "View"; the mailer layout is `<html>` with no `lang`, though the message is rendered in the recipient's locale.
Evidence: `<table role="presentation" id="billing-email-line-items" ...>` with `<thead><tr><th>`; layout line 2 `<html>`.
Impact: Screen reader users lose the column relationships in the invoice summary; link list shows "View"; some clients pick the wrong voice or hyphenation for fr/uk/es. Text part has full parity with the HTML (same helper figures, same order, Taxed marker), which is good.
Fix: remove `role="presentation"`, make the link text "View order" (add key in 4 locales), add `lang="<%= I18n.locale %>"` to the layout.
Blocks: later

##### UX-25 PDF invoice and receipt print dates without the document time zone
Severity: Medium   Confidence: VERIFIED   Effort: S
Where: app/services/better_together/billing/orders/document.rb:43-47,70-72,142 (`def date(time) = time ? I18n.l(time.to_date, format: :long) : nil`)
What: Placed and paid dates on the PDF use `time.to_date`, i.e. the zone the attribute was loaded in (the process default, normally UTC in a job), while the "generated" line and the embedded Factur-X XML and JSON use the resolved document zone (buyer preference, platform, UTC).
Evidence: `time_zone` is passed to InvoiceXml and InvoiceJson and to `generated_text`, but `date(time)` never applies it. Web pages use `l(order.placed_at.to_date)` in the request zone, emails use the recipient zone.
Impact: An order paid at 22:00 in Newfoundland (UTC-3:30) prints the next day on the receipt while the same PDF's XML says the earlier day, and the web page may say a third thing. The date on a tax invoice should be one date everywhere; this also shifts which tax period a filer assigns it to.
Fix: `time.in_time_zone(ActiveSupport::TimeZone[time_zone]).to_date`; guard with a document spec at an offset zone around midnight UTC.
Blocks: merge to main

##### UX-26 Most steward pages are reachable only by typing the URL; only three have nav entries
Severity: Medium   Confidence: VERIFIED   Effort: S
Where: app/builders/better_together/navigation_builder.rb:642-676; app/views/better_together/billing/hubs/show.html.erb; sales/index.html.erb:9-14
What: The host dashboard gets nav items for plans, payment methods and sales only. No link exists anywhere in the UI to subscribers, tax registrations, agreement requirements, promotions, credit accounts, allowances, or the tax reports tab; the sales page links only to the offline queue and walk-up sale (promotions is reachable from credit accounts, which itself is not linked).
Evidence: grep of every `billing_*_path` helper outside app/views/better_together/billing shows only `_user_nav` (hub), the three builder routes and notification links. Nav titles are also given only as `title_en`.
Impact: A steward cannot discover agreement requirements (a billing gate) or tax registrations (needed for tax to apply) without a documentation link; readiness checklist points the steward there in words but not links (except the plant-agreements link). Day-to-day setup is the biggest steward journey gap after the known ones.
Fix: add a "Billing" nav group with all steward pages and link each readiness check to its page; give titles in all four locales. Guard: navigation_builder spec asserting each steward route has an item.
Blocks: later

##### UX-27 Journey gaps confirmed, and ones the story doc missed
Severity: Medium   Confidence: VERIFIED   Effort: L
Where: docs/billing/user_stories_and_coverage.md (stories 1.3, 4.7-4.9, 4.14, gap G3, G20); app/views/better_together/billing/{subscriptions/show,orders/show,orders/index}.html.erb; config/routes/billing.rb:44-57,99-104
What: Confirmed by reading code: no plan change or payment-method change on a subscription (show offers cancel or resume only); no buyer refund request; no billing-address editor (addresses are only created inside checkout); no notification preferences; no order filters or search (index is a plain paginated list); no guest checkout. Missed by the doc:
  (a) A buyer cannot cancel or abandon their own unpaid order; `cancel` is steward only (`post :cancel` under sales, `OrderPolicy#cancel? = sale?`). A wrong method choice keeps an order open until it expires and cannot be re-chosen except by adding a payment.
  (b) Refund amounts and tax are not shown to the buyer (UX-16).
  (c) No "resend receipt or invoice email" action was found (grep for resend in routes, views and controllers is empty); the sale page can only regenerate the PDF.
  (d) The checkout offers no order review of the final total before "Place order" when the address is new (tax unknown until placed: `tax_note_new_address`), so the buyer first sees the taxed total on the order page.
  (e) Story 1.3 says sign-in mid-checkout "loses the selection": `store_user_location!` runs before `authenticate_user!` for GET navigations (ApplicationController:21,418), so `/billing/checkout/new?plan_id=...&payment_method=...` is the stored return path. The doc is probably stale, but sign-up and the POST step were not verified.
Evidence: routes and views above; `before_action :store_user_location!, if: :storable_location?`.
Impact: Support load and abandoned orders; (a) and (d) are the likeliest to cost money (an order for the wrong method, tax surprise).
Fix: add buyer cancel for orders with no payment received, show an estimated tax note with country selection required before the place button, refresh the story doc line for 1.3 after a feature test.
Blocks: later

##### UX-28 Translated content falls back without a `lang` attribute
Severity: Low   Confidence: HYPOTHESIS   Effort: S
Where: app/views/better_together/billing/catalog/*.erb, checkouts/new.html.erb:73-76 (plan.name, description, agreement.title and description), orders/_details.html.erb
What: Plan names and descriptions and agreement titles are Mobility translations that fall back to another locale when missing; no billing view marks them with `lang=`. Only the promotion form marks its translated fields.
Evidence: grep `lang:` in app/views/better_together/billing finds only promotions/new.html.erb:19.
Impact: A French reader of a plan with only an English name gets an English word read with French pronunciation; WCAG 3.1.2. Low because the fallback is rare in practice.
Fix: wrap translated attributes with a helper that adds `lang` when the value came from a fallback locale.
Blocks: later

##### UX-29 Grant summaries show raw identifiers and untranslated words
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/helpers/better_together/billing_entitlement_helper.rb:24-37; app/views/better_together/billing/entitlements/index.html.erb:33-44
What: `billing_plan_grant_summary` interpolates `parameters['role']` (identifier), `parameters['access_level']`, `type.unit` and `type.key.humanize`; the entitlements page names allowances with `grant.quota_type.humanize`. These are English snake-case words in every locale (the sentence frame is translated).
Evidence: `t('...summary_role', role: parameters['role'], ...)`, `grant.quota_type.humanize`.
Impact: Ukrainian buyers read "Storage" / "Ai tokens" in a Ukrainian sentence; role identifiers leak to buyers.
Fix: use role/quota/unit translations (`Role#name`, `Quotas::Type` i18n keys) with the humanized value as default.
Blocks: later

##### UX-30 Chart canvases have no text alternative of their own; report tab uses a disabled tab as a heading
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/metrics/reports/_billing_contents.html.erb:21-23,52-60; billing_reports/_index.html.erb:14-23
What: The revenue canvas carries data attributes only (no `role="img"`, `aria-label`, or fallback content); a `role="tab"` button with `aria-disabled` is used purely as a label; the generated reports table has `<th>` without `scope` and no caption.
Evidence: `<canvas class="metrics-chart" data-... >` with no aria attributes; the same tab shows a per-currency table (the text equivalent), which softens this.
Impact: Screen reader users get no chart summary; the tab pattern announces a disabled tab.
Fix: `role="img"` plus `aria-label` summarizing totals, point to the table; use a heading for the label.
Blocks: later

##### UX-31 Readiness "not done" glyph is yellow on white
Severity: Low   Confidence: VERIFIED   Effort: S
Where: app/views/better_together/billing/shared/_readiness.html.erb:19
What: The unfinished marker "!" uses `text-warning` (#ffc107) on a white card, about 1.6:1, below the 3:1 non-text contrast of WCAG 1.4.11. The glyph is `aria-hidden` with a visually hidden "to do" text, so assistive tech is fine.
Evidence: `<span class="<%= check.ok ? 'text-success' : 'text-warning' %>" aria-hidden="true">`.
Impact: Low-vision stewards may not see which setup items remain; shape (check vs bang) helps.
Fix: use `text-warning-emphasis` or a dark amber, or an icon with a dark outline.
Blocks: later

##### UX-32 i18n key parity result (script run, no defects except UX-07, UX-11, UX-12, UX-29)
Severity: Info   Confidence: VERIFIED   Effort: S
Where: config/locales/{en,fr,es,uk}.yml; the reviewer scratch scripts ux_i18n.rb and ux_i18n2.rb
What: A real YAML flatten and diff of every key containing `billing` (867 keys in en, including `billing_mailer` and the metrics billing keys) found 0 missing and 0 extra keys in fr, es and uk, and 0 interpolation-variable mismatches. Values identical to en: fr 10, es 5, uk 1; sampled, these are legitimate (Total, Subtotal, Description, Actions, Cheque, the registration number template). A scan of 505 static `t('better_together...')` keys used by billing views, helpers, mailers, notifiers, services and JS found 0 missing in en; 54 dynamic-prefix keys were checked for existence of the prefix, and one failed (UX-07, `basiss`).
Evidence: script output "en billing keys: 867; fr/es/uk missing=0 extra=0 interpolation mismatch 0".
Impact: Translation coverage is solid; the remaining i18n work is the hard-coded `aria-label="breadcrumb"` (UX-11), the missing plural machinery (UX-12), raw grant words (UX-29), and the report basis typo (UX-07). Currency formatting is locale-aware and disambiguated (`CA$`, `US$`, `€`, `£` via `Currency.unit`, locale format `%n %u` for fr), dates use `l(..., format: :long)` throughout.
Fix: none needed; add the parity script as a spec if one does not exist (i18n-tasks may already cover it).
Blocks: later


#### 2.2.4 Plan conformance and test adequacy (CONF)

##### CONF-01 Any non-host platform steward can enable local methods and sell, with no hosted agreement gate
Severity: High   Confidence: VERIFIED   Effort: M
Where: app/models/better_together/billing/configuration.rb (`context_for`, `setting_context`), app/policies/better_together/billing/owner_policy.rb:19-22, app/policies/better_together/billing/processor_setting_policy.rb:26-30
What: The decided gates (hosted platform billing agreement, hosted local billing agreement) do not exist, yet a hosted (non-host) platform is not blocked from billing: `context_for` returns a context for any local method once a ProcessorSetting is enabled (`return setting_context(...) if Billing.local_method?(processor)` precedes the `return unless platform.host?` line), and `manage_billing?` accepts any `Platform` owner whose steward holds `manage_platform`.
Evidence: `ProcessorSettingPolicy#billing_available?` uses `Billing.configurable?` (global flag + ready env only, no host check); `Billing.enabled?` then becomes true for that platform as soon as one setting is enabled. Only the purchase-agreement gate (`AgreementGate`) stands between that platform and a sale, and those agreements are per-platform seeds the platform's own steward activates.
Impact: On a multi-platform deployment, a hosted platform's steward enables cash/cheque/e-Transfer, activates the placeholder purchase agreements, and takes orders and records "paid" money with no hosted billing agreement accepted and no liability absolution for the host. Contradicts "every hosted platform must accept the hosted platform billing agreement before any billing" and "only the host Platform sells today".
Fix: Until D3a lands, make `manage_billing?` and `setting_context` require `owner.host?` (fail closed), with a request spec that a non-host platform steward gets 404 on `/billing/processor_settings` and cannot place an order. When D3a lands, replace with the agreement gate.
Blocks: production enablement (any deployment with a second platform)

##### CONF-02 No server-side pause or suspension mechanism exists to honor "pausing must not delete data"
Severity: Medium   Confidence: VERIFIED   Effort: L
Where: app/models/better_together/billing/* (no suspended/paused state), docs/billing/user_stories_and_coverage.md:89,240-246
What: The decision that withdrawing or superseding a hosted agreement pauses the affected billing mode (without deleting) has no code; the only switch is `ProcessorSetting#enabled`, and `destroy?` is false (`processor_setting_policy.rb:13`).
Evidence: grep for suspend/pause/paused across models and services finds no billing state; story rows 0.7 and 2.1d are marked M.
Impact: Correctly unbuilt (D3a), but when hosted gates are built the pause must be a read path check at every payment entry (checkout, walk-up, renewals job, offline confirm). Renewals (`GenerateRenewal`, `AdvanceSubscriptions`) currently never consult a platform-level gate.
Fix: Design the pause as a single `Billing.mode_open?(platform, mode)` consulted by `Orders::Place`, `Orders::AddPayment`, `GenerateRenewal`; spec each entry refuses while paused and keeps rows.
Blocks: later

##### CONF-03 Story coverage doc is stale against merged code (D0, D1a, D1b landed)
Severity: Low   Confidence: VERIFIED   Effort: S
Where: docs/billing/user_stories_and_coverage.md:12-30, 88 (story 0.5 "U"), "Other structural gaps" item 10, story 1.x catalog rows
What: The doc still says there is no public catalog or buyer hub and that free plans are unverified, but `free_plan_checkout_spec.rb`, `hubs_controller_spec.rb`, `catalog_controller_spec.rb` exist and git log shows D0 (#2136), D1a (#2139), D1b (#2141) merged.
Evidence: `git log` at 26e283cb8: "free plans need no payment method (D0)", "buyer billing page (D1a)", "public plan catalog (D1b)".
Impact: Reviewers and planners misjudge what is built; story 0.5 should be B.
Fix: Update the intro, gap 10, story 0.5 and the catalog stories, citing the spec names (the doc names no specs at all).
Blocks: later

##### CONF-04 No real concurrency test exists for double pay, double refund, double redeem or double confirm
Severity: Medium   Confidence: VERIFIED   Effort: M
Where: spec/services/better_together/billing/promotions/redeem_spec.rb:77-89, refunds/record_spec.rb:35, orders/add_payment_spec.rb:93,105, offline_payments/transition_spec.rb:67
What: The code uses `with_lock` 32 times, but every "however many ask" spec runs requests sequentially in one thread; none uses threads, two connections or a lock-order probe.
Evidence: `grep -rn "Thread.new" spec/services/better_together/billing spec/models/better_together/billing` returns nothing. The redeem cap test loops four people one after another (`people.map ... redeem(...)`); it proves the counter logic, not atomicity. The only race-shaped tests are stubbed: `event_ingest_spec.rb:36` (stubbed `find_by`), `event_processor_spec.rb:154` (claim), `add_payment_spec.rb:105` ("two stale copies", which is a good proxy for lost updates).
Impact: Removing a `with_lock` around redeem, refund or confirm would leave the suite green while double spending becomes possible under parallel requests.
Fix: Add one `:concurrency` spec (non transactional examples, two threads with separate connections) each for Promotions::Redeem at the cap, Refunds::Record against the remaining balance, Orders::AddPayment idempotency key, and OfflinePayments confirm; assert exactly one success.
Blocks: production enablement

##### CONF-05 No end-to-end webhook signature or Pay mount spec; signature rejection is untested and delegated to Pay
Severity: Medium   Confidence: VERIFIED   Effort: S
Where: spec/routing/better_together/billing_routes_spec.rb:47-57, spec/services/better_together/billing/pay_webhook_flow_spec.rb, config/routes/billing.rb:24-27
What: The routing spec proves `/pay/webhooks/*` reaches `Pay::Engine` (mocked to return 200) and the flow spec starts after Pay has accepted a delivery, so nothing asserts that a bad or missing signature is refused before an Event row is created.
Evidence: `grep -rn "signature" spec/services/better_together/billing spec/initializers/billing_pay_extensions_spec.rb` finds nothing; `Pay::Engine` is stubbed at `billing_routes_spec.rb:54`.
Impact: A host that mounts Pay differently, or a Pay upgrade that changes verification order, would silently accept forged `payment_succeeded` events; money would be marked paid. Low likelihood today (the only vendor adapter is host only and the fake adapter is test only) but this is the highest-impact trust boundary.
Fix: Add a request spec POSTing to `/pay/webhooks/stripe` with an invalid `Stripe-Signature` and with none (when the stripe adapter is registered) expecting 4xx and zero `Billing::Event` and zero Pay::Webhook rows; keep a valid-signature counterpart built with Stripe's test signing helper.
Blocks: production enablement

##### CONF-06 Agreement acceptance and tenant-isolation guards leave gaps (services, mailers, notifiers unguarded; `find(id)` allowed)
Severity: Low   Confidence: VERIFIED   Effort: S
Where: spec/lib/better_together/billing_tenant_isolation_guard_spec.rb:10-23
What: The isolation guard is a regex over controllers, concerns, policies and jobs only, and permits `X.find(` and `X.find_by(id:`; so services, mailers, notifiers and views are not linted, and a controller `Order.find(params[:id])` would pass.
Evidence: `guarded` list at lines 10-14; negative lookahead `(?!find\(|find_by\(id:|...)` at line 22. I grepped app/controllers, app/mailers, app/notifiers, app/views for bare `Billing::X.find` and found none in controllers (jobs only, by enumerated ids), so there is no live bug; the guard is weaker than its header claims.
Impact: A future IDOR via `find(params[:id])` would not be caught by the guard; only per-controller "another platform" request specs (25 files mention it) would catch it.
Fix: Extend the guard to forbid class-level `find`/`find_by` in `app/controllers` (not jobs), and add `app/services` and `app/notifiers` with an allow list.
Blocks: later

##### CONF-07 Billing params are not in `filter_parameters` except `promotion_code`; buyer email, address and payee settings reach request logs
Severity: Medium   Confidence: HYPOTHESIS   Effort: S
Where: lib/better_together/engine.rb:153-155, spec/dummy/config/initializers/filter_parameter_logging.rb:6-8, app/controllers/better_together/billing/walk_up_sales_controller.rb:63-66
What: The engine adds only `promotion_code` (plus federation secrets) to `filter_parameters`; the dummy default list (`passw secret token _key crypt salt certificate otp ssn`) has no `email`, so `buyer_email`, `billing_address[...]`, `buyer_reference` and offline `settings` (payee details) are logged in plain text by Rails request logging.
Evidence: walk-up permits `:buyer_name, :buyer_email` and a `billing_address` hash; the only billing spec of filtering is `promotion_redemptions_controller_spec.rb:62`. Host apps may add their own list (not checked), hence HYPOTHESIS. The encryption doc's whole point (`docs/billing/encryption.md`) is undone if the same values appear in logs.
Impact: Buyer personal data and payee details (e-Transfer address, cheque payee) land unencrypted in log files and any log shipper (Loki).
Fix: Add `buyer_email billing_address buyer_reference buyer_name` and the offline settings keys to the engine initializer; extend the guard spec to assert `Rails.application.config.filter_parameters` filters each.
Blocks: production enablement

##### CONF-08 Tax rounding is tested for one line only; multi-line, mixed-rate and tax-inclusive remainder cases have no calculator spec
Severity: Low   Confidence: VERIFIED   Effort: S
Where: spec/services/better_together/billing/tax/calculator_spec.rb:40-43, app/services/better_together/billing/tax/calculator.rb:163
What: `tax_amount` rounds half up per amount, and the spec proves only 10c and 9c at one rate.
Evidence: `grep -n "multiple lines\|several lines\|per line"` over the calculator spec finds nothing; refund pro-rating to the cent is covered (`refunds/record_spec.rb:75`) and per-tax report merging is covered, but the order level invariant "sum of line taxes equals order tax equals invoice tax" is not.
Impact: A change from per-line to per-order rounding, or an inclusive-price remainder bug, would shift tax by a cent per order and drift from the invoice and remittance.
Fix: Add calculator specs for 3 lines at 5 and 9.975 percent exclusive and inclusive, asserting the sum of line taxes equals the order tax and `price - tax` equals net, plus a zero-decimal currency (JPY) case.
Blocks: later

##### CONF-09 Docs and diagrams have drifted from code (five spot checks)
Severity: Low   Confidence: VERIFIED   Effort: S
Where: docs/billing/platform_isolation.md:39, docs/billing/hosted_billing_roadmap.md (Already in place), docs/diagrams/source/billing_schema_erd.mmd, docs/diagrams/source/billing_order_lifecycle_flow.mmd:18-27, docs/billing/user_stories_and_coverage.md
What: (1) platform_isolation.md:39 says any non-host platform has no processor context so billing is off; false for local methods (see CONF-01). (2) The ERD lists 27 entities but omits billing_tax_categories, tax_zones, tax_rates, tax_registrations, tax_lines, default_addresses, order_documents and billing_reports (all have migrations; grep of both ERD sources finds none). (3) The order lifecycle diagram marks `refunded` as terminal and has no `refunded -> paid/partially_refunded` or `partially_refunded -> paid`, but `Order::TRANSITIONS` (order.rb:33-36) allows them for a failed refund. (4) The story doc predates D0/D1a/D1b (CONF-03). (5) The roadmap's "Left for later" omits the hosted agreements and pause gates that the story doc defines (G22), so the two plan docs disagree on what remains.
Evidence: `grep -il` of each table name over both ERD files returned empty; TRANSITIONS lines 33-36 vs diagram lines 18-27.
Impact: Reviewers and the legal-review step rely on the diagrams; the isolation doc would mislead an auditor into thinking hosted platforms cannot bill today.
Fix: Update the four docs; the repo's `bin/check_diagrams` should be extended to fail when a `better_together_billing_*` table is missing from the ERD source.
Blocks: later

##### CONF-10 Refund and SubscriptionPeriod accept any status change at model level, and no model has an exhaustive transition spec
Severity: Low   Confidence: HYPOTHESIS   Effort: M
Where: app/models/better_together/billing/refund.rb:14-22, subscription_period.rb:20-30, spec/models/better_together/billing/order_spec.rb:112-113
What: Order, OfflinePayment and Payment validate transitions on update; Refund (`pending succeeded failed recorded`) and SubscriptionPeriod (`pending needs_agreement blocked paid waived lapsed`) only check inclusion, so a `paid` period or `succeeded` refund can be written back to `pending` by any caller.
Evidence: grep for `TRANSITIONS|status_transition` in refund.rb and subscription_period.rb finds nothing. I did not find a caller that does this; services guard by convention.
Impact: A future code path or console fix could un-pay a period (re-granting an entitlement) or re-open a refund (re-sending money). Defence in depth only.
Fix: Add TRANSITIONS and `status_transition_allowed` to both, and a table driven spec per model that asserts every legal pair passes and every other pair fails.
Blocks: later

##### CONF-11 Six specs that guard "placeholder agreements can never sell" fail on this commit, deterministically
Severity: High   Confidence: VERIFIED (failure), HYPOTHESIS (cause)   Effort: S to M
Where: spec/services/better_together/billing/purchase_agreement_seeds_spec.rb:12, checkout_spec.rb:43,211,233, orders/place_spec.rb:103, requests/.../checkouts_controller_spec.rb:144; code under test app/services/better_together/billing/purchase_agreement_seeds.rb:55-80,21
What: After `PurchaseAgreementSeeds.call(platform)` the seeded agreements have `lifecycle_state: 'active'` (lock_version 2) instead of `draft`, so `AgreementGate` reports ready and a platform with placeholder legal text can sell.
Evidence: Full run (seed 33976): 6 failures, all agreement-draft specs. A rerun of the seeds spec, `checkout_spec.rb:43` and `place_spec.rb:103` alone with a different seed (60361) fails the same three, so it is not order dependent. Failure diff: `-:lifecycle_state => "draft"  +:lifecycle_state => "active"`; Readiness reports `agreements ok=true detail=[]`.
Impact: If real, the seeded placeholder terms are in force from day one, defeating the documented safeguard ("until a steward reviews and activates them nothing can be sold", purchase_agreement_seeds.rb:11-15). A buyer would "accept" lorem-style placeholder terms on a live platform. If the cause is test setup (e.g. `configure_host_platform` or `Seed.import_or_update!` creating the records before the draft attributes apply), the production path may still be safe but the guard specs are then red and do not protect anything.
Fix: Determine whether `Seed.import_or_update!(packet)` (called first in `#call`) or the `AgreementBuilder` creates the agreements as active before `find_or_create_by!(...) { assign DRAFT_ATTRIBUTES }` runs (the block applies only to NEW records). Apply `lifecycle_state: 'draft'` on the create path of whatever makes the row, and keep the existing specs as the guard. Do not merge with red safety specs.
Blocks: merge to main


## 3. Plan conformance and test gaps (from CONF)

### 3.1 Conformance table (decisions and gates)


| Decision / gate | Status | Evidence |
|---|---|---|
| Hosted platform billing agreement (gate for any billing on a non-host platform) | Missing (planned D3a/G22) | No agreement kind, seed or gate for it: `app/services/better_together/billing/purchase_agreement_seeds.rb:5-9` seeds only subscription, one-time, offline terms. grep for hosted/merchant in app/config/db finds nothing in billing gates. |
| Hosted local billing agreement (cash, cheque, e-Transfer) | Missing (D3a) | `Configuration.setting_context` (`app/models/better_together/billing/configuration.rb:~100`) grants a local-method context to ANY platform once a steward enables a ProcessorSetting; no agreement check. See CONF-01. |
| Merchant onboarding agreement / MoR gating | Missing (D9, correctly unbuilt) | No code path; `processor_adapter.rb:40` has only a `merchant_accounts` capability stub. |
| Own processor connection gate (per-platform credentials) | Missing (D8, correctly unbuilt) | `configuration.rb:60` `return unless platform.host?` so vendor processors are host only. Honors "only host sells vendor processors today". |
| Local-methods gate (no processor needed, needs agreement) | Partial | Local methods need no processor (`configuration.rb:59`), but the "needs hosted local agreement" half is absent. Purchase agreements (`Checkout::AgreementGate`) exist and fail closed. |
| Purchase agreement gate server-side | Implemented | `app/services/better_together/billing/checkout/agreement_gate.rb:14-50`; enforced in `orders/place.rb:85`, `offline_payments/walk_up.rb:116`, `subscriptions_controller.rb:64`, `checkouts_controller.rb:84`. Seeds are drafts so nothing sells until activated (`purchase_agreement_seeds.rb:11-15`). |
| Pause without delete | Missing (D3a) | No pause/suspend concept in models; ProcessorSetting `enabled` flag only. `destroy? = false` in `processor_setting_policy.rb:13` protects data. |
| `Pay.send_emails = false` | Implemented | `config/initializers/pay.rb:6`; guarded by `spec/lib/better_together/billing_notification_guard_spec.rb:16-17`, which also forbids Pay mailer calls in billing code. |
| One shared `Orders::Summary` for web/email/PDF/offline/checkout | Implemented | Web: `views/better_together/billing/orders/_details.html.erb:37`; checkout `checkouts/new.html.erb:23` via `TaxPreview#summary` (`checkout/tax_preview.rb:31`); offline instructions `orders/_offline_payment.html.erb:18`; email `notifiers/billing/notifier.rb:51` + `billing_summary_helper.rb`; PDF/XML/JSON `orders/document.rb:30,54,56`. Guarded by `spec/requests/better_together/billing/order_summary_surfaces_spec.rb`. |
| Encrypted credentials / PII | Implemented | `encrypts_billing_attribute` on Event payload+error, ProcessorSetting settings, Order buyer_email+billing_address, TaxLine registration_number, OfflinePayment buyer_reference, Pay webhook event and Pay data (`pay_extensions/encrypted_billing_data.rb:31`, `encrypted_webhook_event.rb:22`). |
| Platform scoping on every table | Implemented | All billing models include `PlatformBound` or `belongs_to :platform`; only ApplicationRecord, Configuration, PayRecord, ProcessorContext, TaxReport (PORO) and UnattributableWebhookError lack it, all non-persistent or by design. Pay tables carry platform_id with composite FKs (`db/migrate/20261015120000_create_better_together_pay_tables.rb:6-14`); `pay_webhooks` intentionally has none. |
| Only host Platform sells today / seller UI deferred | Partial | `OwnerPolicy#manage_billing?` (`app/policies/better_together/billing/owner_policy.rb:19-22`) allows ANY Platform owner whose `manage_platform` the user holds, not host only; vendor processors are host only, but local methods are not. See CONF-01. |
| Direct checkout, no cart | Implemented | `checkouts_controller.rb` single `purchasables: [@plan]` (confirmed in story doc line 19). |

### 3.2 Covered stories sampled against specs


The story doc names no specs, so I matched each B story to the closest spec and read its examples.

| Story | Spec found | Asserts the behavior? |
|---|---|---|
| 0.1 plans with quota allowances | `requests/.../plans_controller_spec.rb`, `plan_grants_controller_spec.rb`, `services/.../entitlements/quota_allowances_spec.rb` | Yes |
| 0.2 feature access and role grants | `services/.../entitlements/handlers/*`, `entitlement_models_spec.rb` | Yes (handlers) |
| 0.3 quota override without a plan | `requests/better_together/quota_grants_spec.rb`, `quota_grant_spec.rb` | Yes |
| 0.4 enforcement mode and usage | `allowances_controller_spec.rb:33-82` | Yes (mode change, refusal, usage, over-limit) |
| 0.9 tax and revenue report | `models/.../tax_report_spec.rb:23-97` (+ csv, chart_data) | Yes, including period edges and currencies |
| 1.15 several currencies with tax | `currency_spec.rb`, `plan_snapshot_spec.rb`, `tax_report_spec.rb:44` | Partial: no multi-currency checkout-with-tax end to end |
| 2.9 receipt and invoice, tax per line | `orders/generate_document_spec.rb:87-99` (Factur-X XML, JSON-LD taxed lines, Quebec tax) | Yes for XML/JSON; PDF text is not asserted by content (`pdf_attachments_spec` only attaches) |
| 2.11 accept terms before paying | `checkouts_controller_spec.rb:133-283`, `place_spec.rb:120` | Yes, strong (crafted request, drafts, not-applicable box) |
| 2.12 renew by cheque/e-Transfer, admin confirms | `offline_payments_controller_spec.rb`, `offline_payments/transition_spec.rb` | Yes |
| 3.15 cash at a meeting (walk-up) | `walk_up_sales_controller_spec.rb:74-187` | Yes |
| 4.4 cancel at period end, resume | `subscriptions_controller_spec.rb:55-84` | Yes |
| 4.11 credit, lots, expiry, redeem code | `credits_controller_spec.rb`, `promotion_redemptions_controller_spec.rb`, `credit/*` | Yes |
| 4.12 accept changed agreements (`needs_agreement`) | `subscriptions_controller_spec.rb:106`, `generate_renewal_spec.rb`, `needs_agreement` at :109 | Yes |

Result: 13 sampled, 12 fully asserted, 1 partial (1.15). Story 0.5 is marked U but `free_plan_checkout_spec.rb` and `free_plans_spec.rb` now cover it (stale, CONF-03).

### 3.3 Test adequacy for high-risk behavior


| Behavior | Spec path | Adequate? | Gap |
|---|---|---|---|
| Webhook signature | none (Pay engine stubbed in `spec/routing/better_together/billing_routes_spec.rb:54`) | No | CONF-05 |
| Webhook idempotency and attribution | `services/.../event_ingest_spec.rb:27-54`, `pay_webhook_flow_spec.rb:30-50`, `event_processor_spec.rb:131-164` | Yes (duplicate, cross-platform refusal, unattributable keeps row, claim contention) | Concurrency is simulated by stubs, not threads |
| Replay authorization | `services/.../replay_event_spec.rb` | Not examined in depth (see Not checked) | |
| Double pay | `add_payment_spec.rb:93,105`, `payments_spec.rb:22,63` | Mostly (idempotency key, stale copies) | No parallel test (CONF-04) |
| Double refund | `refunds/record_spec.rb:35,41` | Sequential only | CONF-04 |
| Double redeem | `promotions/redeem_spec.rb:69-89,125` | Sequential only; atomic increment checked by stub | CONF-04 |
| Refund caps and pro-rated tax | `refunds/record_spec.rb:41,67-93`, `credit_refund_spec.rb` | Yes (remaining, cent-exact pieces, part-paid) | |
| Tax rounding | `tax/calculator_spec.rb:40` | Thin | CONF-08 |
| Cross-tenant access | 25 request/service/policy specs with "another platform"; `spec/lib/.../billing_tenant_isolation_guard_spec.rb`; DB-level `payment_spec.rb:88`, `order_agreement_acceptance_spec.rb:62` | Good | Guard permits `find(id)`, skips services (CONF-06) |
| Agreement gate bypass | `checkouts_controller_spec.rb:257-283`, `place_spec.rb:120`, `walk_up_sales_controller_spec.rb:187` | Yes at checkout and walk-up | Renewals go through `Orders::Place` (generate_renewal.rb:66, `needs_agreement` covered in `generate_renewal_spec.rb`); fine |
| Acceptance immutability | `order_agreement_acceptance_spec.rb:37` ("never rewritten") plus `readonly?` (model:49) | Yes | |
| Throttles | `processor_options_throttle_spec.rb`, `order_pay_throttle_spec.rb`, `order_documents_throttle_spec.rb`, `spec/config/rack/billing_credit_throttles_spec.rb` | Partial | Credit throttle spec calls the block directly (limits and keys), not through the middleware; no throttle at all for checkout create, walk-up, refunds, claims, agreement acceptance (SEC area) |
| State transitions | `order_spec.rb:112` (`can_become?` two assertions), `offline_payments/transition_spec.rb`, `settle_spec.rb` | Order and OfflinePayment have a TRANSITIONS table; Payment has `status_transition_allowed` (payment.rb:98); Refund and SubscriptionPeriod have none | No exhaustive illegal-transition spec for any model (order_spec asserts one legal and one illegal move) (CONF-10) |
| Filter parameters / PII in logs | `promotion_redemptions_controller_spec.rb:62` only | No | CONF-07 |
| Billing off is inert / 404 before sign-in | `*_controller_spec` "is a 404 while billing is off" (credits, offline, promotion redemptions, ...) | Good | |
| Pay emails off | `spec/lib/better_together/billing_notification_guard_spec.rb` | Yes | |

### 3.4 Spec baseline (one run)


Command: `WORKERS=3 ./bin/dc-run bundle exec rspec spec/requests/better_together/billing spec/services/better_together/billing --format progress` (plain rspec, one process; harness worked).
Result: 1192 examples, 6 failures, 14 min 45 s, seed 33976. Failures (all CONF-11, same root, all agreement drafts):
- requests/.../checkouts_controller_spec.rb:144
- services/.../purchase_agreement_seeds_spec.rb:12
- services/.../checkout_spec.rb:43, :211, :233
- services/.../orders/place_spec.rb:103
Rerun of three of them in isolation with another seed: same failures (deterministic). No other flakes seen (rspec-rebound retries were not reported). Not debugged beyond locating the divergence.


## 4. Old branch (PR #1581) assessment and reuse map

OLD = `ce-billing-1581-old` (39a44e378). CURRENT = `ce-billing-assess` (26e283cb8). Copied from OLD.md; headings demoted one level.

### 4.1 Headline

The headline result: CURRENT has already ported and hardened almost everything on the event pipeline that the owner wants
from OLD. The dead-letter sweep, payload redaction, replay service, ingest idempotency, unattributable-event handling,
claim lease, retry backoff, encrypted payloads, queue routing, cron entries, operator notification, pipeline diagram and
specs all exist in CURRENT and are better than OLD. Copying OLD files over them would be a regression.

What CURRENT genuinely lacks (and OLD can seed) is small:

1. An operator UI for events (alerts card, list, replay button). OLD has the card and the controller action. CURRENT has none (`grep Billing::Event` in views/controllers/policies/routes finds nothing).
2. Rake tasks for `Billing::Event` (list, replay). Neither tree has them. Write them new (about 30 lines), do not copy.
3. A Stripe adapter. CURRENT has only `InternalProcessorAdapter`, `OfflineProcessorAdapter` and the cash/cheque/e-transfer/store-credit adapters; Stripe is meant to come through Pay. The OLD Stripe sync services, sanitizer and price/plan sync are the raw material for that adapter. This is the only large reuse opportunity, and it is COPY AND ADAPT, not copy.
4. A webhook operations runbook. CURRENT has `docs/production/billing_queue_rollout.md` (queues only) and the pipeline diagram, but no operator runbook for "what do I do with a dead-lettered event".
5. Scheduled reconciliation against the processor (scan jobs). CURRENT has `ProcessorAdapter#reconcile_payment` in the contract but no scan job calls it.

### 4.2 Defects that would be inherited by copying OLD code (OLD-01 to OLD-08)

Full text is in `parts/OLD.md` section A4. Summary:

| ID | Severity | What | Resolution |
|---|---|---|---|
| OLD-01 | High | Full webhook payload passed as a job argument (PII into Redis, retry sets, logs) | Do not copy; CURRENT job takes the event id only |
| OLD-02 | High | Event payload and error text stored plaintext | Keep CURRENT encrypted columns |
| OLD-03 | Medium | No row lock or claim lease on event processing | Use CURRENT `EventProcessor` |
| OLD-04 | Medium | Dead-letter threshold 3 below job retry ceiling 10; ignored events swept; replay does not reset attempts | CURRENT already fixes all three |
| OLD-05 | Medium | Sweep dead-letters without re-check under lock; one bad row aborts the loop | CURRENT has lock re-check and per-row rescue |
| OLD-06 | Low | Reconcile scan lock couples to Sidekiq Redis; unordered limit; wrong queue | If ported: advisory lock, ordered batches, billing queue |
| OLD-07 | Low | Replay has no authorization of its own | Gate on operator policy in whatever caller is built (SEC-02) |
| OLD-08 | Low | Stripe-named, hardcoded processor list and `:maintenance` queue | CURRENT uses the billing queue and validates the processor format |

### 4.3 Open CURRENT findings versus OLD

| Finding | Would OLD fix it? |
|---|---|
| PERF-09 no operator replay entry, pending events not re-enqueued, kill switch env only | No. OLD has no rake task, no re-enqueue of pending events, no runtime kill switch. Only the controller `replay_event` action is reusable as a pattern, and it is owner-scoped, not operator-gated. Write rake tasks fresh. |
| SEC-02 ReplayEvent has no authorization/caller | No. OLD's only caller authorizes by owner scoping (see OLD-07). |
| PERF-06 lock order | No. OLD has no `DeadlockRetry` and no documented order. |
| PERF-14 billing-off gating | No. OLD gates nothing on a flag; its Stripe jobs run regardless. |
| SEC-15 test gaps | Partly. OLD has `stripe_event_processor_spec` (479) and a 887-line community request spec, but none are concurrent, cross-tenant-matrix or Pay-mount specs. Nothing to copy. |
| SEC webhook/event findings (SEC-01..16) | None are fixed by OLD; the OLD design is weaker on every webhook point (OLD-01..05). |

### 4.4 Copy map (dependency order)

Legend for "mechanical": `cp` plus `sed` is enough; "hand" means edit after copy. Nothing in the pipeline layer (dead-letter, redact, replay, ingest, dispatcher, processor, job, event model, cron, factory, specs) should be copied: CURRENT is ahead. Note: the table's row labels C-1 to C-10 are as in OLD.md (the headline text refers to some rows by earlier numbers).

| # | OLD path -> CURRENT path | Verdict | Adaptations | Specs | Risk |
|---|---|---|---|---|---|
| C-1 | none (new) `lib/tasks/better_together/billing.rake`: add `list_events[status]`, `replay_event[id]` | write new, 30 lines, extend existing rake file | `list_events`: `Billing::Event.problematic.newest_first.limit(50)`, print `id platform_id processor event_type processing_status attempt_count`, never payload or error text. `replay_event`: `Billing::ReplayEvent.call(billing_event:, requested_by: <operator Person from ENV/arg>)`, print `result.reason`. Needs a person argument because `mark_replay_requested!` stores `requested_by.id`. Also add `enqueue_pending` (re-enqueue `Event.pending` older than 10 minutes, `unclaimed`) to close PERF-09. No OLD source exists. | new `spec/tasks/better_together/billing_events_rake_spec.rb` (model on OLD `spec/tasks/better_together/billing_sponsorships_spec.rb`, 47 lines, for the Rake-loading boilerplate) | Low |
| C-2 | `$O/app/jobs/.../dead_letter_stale_billing_events_job.rb` | USE CURRENT | none; but add the pending re-enqueue step (PERF-09) to CURRENT's sweep by hand: before dead-lettering, re-enqueue `pending` events with `attempt_count == 0` and no claim | extend CURRENT `dead_letter_stale_billing_events_job_spec.rb` | Low |
| C-3 | `$O/app/views/better_together/shared/_billing_event_alerts.html.erb` (166 lines) -> `$C/app/views/better_together/billing/events/_alerts.html.erb` | COPY AND ADAPT | Needs: (a) rename i18n keys `better_together.billing.*` to a new `better_together.billing.events.*` namespace and use `t(..., default:)` removal plus real keys in en/fr/es/uk (i18n-tasks is enforced); (b) drop `ignored_count` (CURRENT's `operator_alert_summary` has `alerted_count`, no `ignored_count`); (c) replace "Stripe webhook activity log" with a processor-neutral label using `event.processor`; (d) replace the `billing_alert_events`/`billing_alert_summary` helper calls with locals passed by the caller; (e) never render `payload` or `error_message` (OLD table at lines ~70-166 prints them; CURRENT encrypts them for a reason), show id, type, status, attempts, dead_letter_reason; (f) add a Replay button only for `dead_lettered? && replayable_payload?` via button_to to a new route; (g) stable DOM ids and a `spec/dom_contracts/billing_events_spec.rb` (CE view rule). Mechanical part: `cp "$O/app/views/better_together/shared/_billing_event_alerts.html.erb" "$C/app/views/better_together/billing/events/_alerts.html.erb"` then `sed -i "s/better_together\.billing\./better_together.billing.events./g"`. Everything else by hand. | new request spec for the controller (below), dom contract, i18n-tasks | Medium (view PR needs screenshots, annotated desktop and mobile, per CE rules) |
| C-4 | OLD `controller_concern.rb` lines 86-92, 301, 376-385 (replay action, flash) -> `$C/app/controllers/better_together/billing/events_controller.rb` (new) + `$C/app/policies/better_together/billing/event_policy.rb` (new) + route `resources :events, only: %i[index] { post :replay, on: :member }` in `config/routes/billing.rb` | COPY AND ADAPT the logic only; do not copy the 415-line concern | Controller: `index` (problematic events for `current_platform`, `policy_scope`), `replay` calls `Billing::ReplayEvent.call(billing_event: event, requested_by: current_user.person)`. Policy: subclass `OwnerPolicy` like `ProcessorSettingPolicy`, `index?`/`replay?` = `manage_billing?` and host-platform operator (closes SEC-02). Scope events through `platform.billing_events`, never class-level. Redirect with `status: :see_other`. Flash strings: lift the three outcomes from OLD `replay_event_flash` (enqueued, not dead-lettered, payload unavailable) and add `unsupported_processor`/`platform_not_configured` (CURRENT's two extra reasons). Hand work. | new `spec/requests/better_together/billing/events_controller_spec.rb`: steward ok, non-steward refused (SEC-02), other platform 404, redacted payload refused, no payload in HTML | Medium |
| C-5 | `$O/docs/payments-stripe-webhook-operations.md` (135 lines) -> `$C/docs/production/billing_webhook_operations.md` | COPY AND ADAPT (rewrite about 70 percent) | Keep: Processing Contract bullet style, Required Operational Expectations, Manual Reconciliation list, retention statement. Replace: sequence diagram (use `billing_event_pipeline_flow.mmd`), "Stripe events subscribed" list (comes from the adapter's `webhook_subscriptions`), merchant event sections (move to the Stripe adapter doc later). Add: how to read `list_events`, replay and when not to, what `dead_lettered`/`alerted` mean, retention env `BT_BILLING_EVENT_PAYLOAD_RETENTION_DAYS`, `pay_webhooks`/`reprocess_pay_webhook` for unattributable deliveries, queue and cron names, who is notified (`event_dead_lettered`). `cp "$O/docs/payments-stripe-webhook-operations.md" "$C/docs/production/billing_webhook_operations.md"` then edit; no sed will do. Run `./bin/dc-run` mermaid render only if a diagram is added. | none | Low |
| C-6 | `$O/app/services/better_together/billing/stripe_event_payload_sanitizer.rb` (169) -> future `app/services/better_together/billing/processors/stripe/payload_sanitizer.rb` | COPY AND ADAPT, deferred until a Stripe adapter exists | Rename class to `Processors::Stripe::PayloadSanitizer`, wrap as the adapter's `sanitize_payload(payload)`. Constants (`ROOT_KEYS`, `OBJECT_KEYS` per subscription, checkout.session, account, invoice, charge) copy as is. Add the fail-closed default: unknown `data.object.object` returns `payload.slice('id','type')` (OLD falls through). Drop Connect `account` keys unless Connect is kept. `cp` then `sed -i 's/StripeEventPayloadSanitizer/Processors::Stripe::PayloadSanitizer/'` works for the rename. | `$O/spec/services/.../stripe_event_payload_sanitizer_spec.rb` (55) with the same sed; add an unknown-object case and a "no email/address survives" case | Medium (an over-wide whitelist leaks PII; review every key) |
| C-7 | Stripe event handlers: `$O/app/services/.../stripe_event_processor.rb` (334), `stripe_subscription_sync.rb` (89), `stripe_checkout_session_sync.rb` (234), `stripe_financial_event_sync.rb` (248), `stripe_one_time_payment_sync.rb` (90) -> future `processors/stripe/{event_handler,subscription_sync,checkout_session_sync,...}.rb` and `adapter.process_event` / `adapter.sync_checkout_session` | COPY AND ADAPT, large, only when the Stripe adapter is scheduled | These write OLD models (`Billing::Subscription` with `billable_owner`/`beneficiary`, `StripeEvent` rows, `Billing::Event#billing_subscription`). CURRENT replaced these with Pay extensions (`pay_extensions/*`) and orders/payments. Each handler needs rewriting to return `EventResult` (`processed`/`ignored`/`retry`/`alerted` plus `outcome_kind`) and to take `context:`. Raise `EventProcessor::RetryableError` where OLD returned "subscription not found yet". Not a cp/sed job; use OLD as the reference for Stripe field mapping only. | port the matching OLD specs as shared examples against `spec/support/shared_examples/billing_processor_adapter.rb` | High (largest effort in this map; money paths) |
| C-8 | `$O/app/jobs/.../reconcile_stripe_billable_owner_billing_scan_job.rb` (58) and `reconcile_stripe_billable_owner_billing_job.rb` (19) -> `$C/app/jobs/better_together/billing/reconcile_payments_scan_job.rb` + `reconcile_payment_job.rb` | COPY AND ADAPT, after C-7 | Scan target becomes stale `pending`/`processing` `Billing::Payment` rows (not `Pay::Customer`), per-row job calls `adapter.reconcile_payment(context:, payment:)`. Replace `< BetterTogether::ApplicationJob` with `< ApplicationJob` (billing queue), delete `queue_as :maintenance`, replace the Redis lock with `pg_try_advisory_lock` (or drop it: the per-row job is idempotent), add `.order(:id)` and a batch limit. Register in `config/sidekiq_scheduler.yml` with no `queue:` key (comment at line 52 says the job decides). Gate on `Billing::Configuration.requested?` (PERF-14). `cp` + `sed -i 's/ReconcileStripeBillableOwnerBilling/ReconcilePayments/g; s/BetterTogether::ApplicationJob/ApplicationJob/; /queue_as :maintenance/d'` is the mechanical half. | OLD `reconcile_stripe_billable_owner_billing_scan_job_spec.rb` (39) with the same sed, then rewrite fixtures | Medium |
| C-9 | `$O/app/jobs/.../sync_plan_to_stripe_job.rb`, `backfill_stripe_product_ids_job.rb`, `services/stripe_plan_sync.rb`, `stripe_price_sync.rb` | IGNORE for now (CURRENT has `SyncPlanJob` + `adapter.sync_plan`); mine `stripe_plan_sync.rb`/`stripe_price_sync.rb` only when writing the Stripe adapter's `sync_plan`/`fetch_price` | none now | none | Low |
| C-10 | `NotifyHostedAccessGraceJob`, `HostedAccessGraceNotifier`, `CheckoutSessionSyncBroadcaster`, `MerchantAccount` + `stripe_connect/*`, sponsorship services/notifiers/policies, `BenefitCredit`, `MonetaryContribution`, `community_billings`/`person_billings` | IGNORE | superseded or product-undecided (see A3). `NotifyHostedAccessGraceJob`'s "mark sent only when someone was notified" pattern is worth copying into CURRENT's `grace_ending` delivery if it lacks it (check `RemindRenewalsJob`). | none | n/a |

### 4.5 Recommended copy order (independently committable batches)

1. **Batch 1, operator tooling (no UI):** C-1 rake tasks plus the pending re-enqueue step in C-2. Closes PERF-09 and half of SEC-02. Validate: `./bin/dc-run bundle exec rspec spec/tasks/better_together/billing_events_rake_spec.rb spec/jobs/better_together/billing/dead_letter_stale_billing_events_job_spec.rb spec/services/better_together/billing/replay_event_spec.rb spec/models/better_together/billing/event_spec.rb` (run from repo root, `WORKERS` irrelevant for a single run).
2. **Batch 2, operator UI:** C-3 + C-4 (events controller, policy, route, alerts partial, i18n in four locales, dom contract, screenshots and docs spec per the CE view rules). Validate: `... rspec spec/requests/better_together/billing/events_controller_spec.rb spec/dom_contracts/billing_events_spec.rb spec/policies/better_together/billing/event_policy_spec.rb` and `i18n-tasks health`.
3. **Batch 3, runbook:** C-5 docs plus a link from `billing_queue_rollout.md` and the pipeline diagram. Validate: markdown links and `bin/render_diagrams` only if a diagram changed. No specs.
4. **Batch 4, Stripe adapter groundwork (only if Stripe via a custom adapter is in scope; otherwise stop at 3):** C-6 sanitizer, then C-7 handlers behind the adapter contract, then C-8 reconcile scan. Validate: `... rspec spec/services/better_together/billing/processors/stripe spec/jobs/better_together/billing/reconcile_payments_scan_job_spec.rb spec/services/better_together/billing/pay_webhook_flow_spec.rb` with the shared adapter examples.

### 4.6 Decisions the owner must make (OLD.md C3, verbatim)

1. Is a first-party Stripe adapter in scope, or does Stripe stay on Pay's own handlers plus `Pay::Webhook` reprocessing? Batch 4 and every Stripe row depend on this; if Pay-only, C-6 to C-9 become IGNORE.
2. Who may replay events: host-platform steward only, or also each platform's billing manager? (Replay re-runs processor side effects; recommendation: operator only.)
3. Should the events page be per platform (platform manager sees own events) or host-wide? Events are platform-bound, so per platform is natural; host-wide needs a deliberate cross-tenant policy.
4. Add a runtime platform-level billing pause (PERF-09, PERF-14) in the same PR as the events page, or separately?
5. Keep Stripe Connect merchant onboarding and sponsorships/community billing (dropped by CURRENT), or confirm they are out of scope?
6. Sentry: add `Rails.error.report` calls to the sweep rescue and `EventProcessor.fail_with` now (cheap), or wait for the Sentry integration decision?
7. Pending-event re-enqueue interval and whether events stuck `pending` should alert before dead-lettering at 6 hours.

## 5. Positives (merged)

Security and tenancy
- Every billing controller includes `OwnerScoped` (404 before sign-in when billing is off, then `authenticate_user!`) and has `after_action :verify_authorized`; the only `skip_before_action` is the public catalog, which uses a policy scope and 404s for unlisted plans.
- All by-id lookups go through `billing_owner.billing_*` plus `bought_by(current_user.person)` or `sold_by_platform`; no `unscoped`; `platform_id` is never permitted in any `.permit`. Platform scoping is structural: every billing model includes `PlatformBound` or ties to its platform, Pay tables get composite FKs, and a lint spec forbids bare class-level reads in controllers, policies and jobs.
- Prices, tax, quantity and currency are recomputed on the server in `Orders::Place`; the buyer supplies only a method, address and validated part amounts.
- Money and identity data are encrypted with `support_unencrypted_data: false` and a boot-time column check (event payloads, order buyer email and address, processor settings, registration numbers, offline references); a redaction job exists for old payloads.
- Self-confirmation of an offline payment is refused, steward credit to self is refused, CSV export neutralises formulas on most columns, tax numbers are masked in reports.
- Brakeman: 0 warnings, 0 errors; bundler-audit: no vulnerabilities.

Webhooks, events and operations
- Webhook handling is idempotent and fail-closed: path-restricted Pay mount, `UnattributableWebhookError` keeps the Pay row, a global (processor, event_id) unique key with a cross-platform conflict error, claim lease plus row lock in `EventProcessor`, hourly dead-letter sweep with operator notification, payload redaction with a Redis lock.
- Notifications are sent after commit with per-recipient dedupe receipts and `deliver_later`, so no email, PDF or HTTP work runs under a row lock and a deadlock retry does not double-send.
- Billing has its own `billing` queue, Pay jobs are routed onto it, sweep jobs rescue per record and report class names only, and cron times are staggered with no `queue:` override.
- Every migration is guarded (`table_exists?`, `column_exists?`, `index_name_exists?`), has `up` and `down`, and adds NOT NULL columns with defaults or backfills first; the one refusal case is explicit.
- `Billing.enabled?` is memoized per request and short-circuits on ENV before any query; "billing off" gives 404 before sign-in, with per-controller specs.
- `Pay.send_emails = false` is guarded by a spec that also scans billing code for Pay mailer use.

Correctness and tests
- Refund caps are enforced in the model under the payment row lock with idempotency keys; pro-rated tax is capped and the last refund takes the remainder; refund specs are strong (remaining caps, cent-exact pieces, part-paid orders, repeated request returns the same refund).
- `TaxReport` is pure SQL aggregates with Arel: a fixed handful of queries regardless of span, no raw SQL strings, currencies never mixed, platform scoped on every join. The tax calculator memoizes rates and zones per call; document generation is fingerprinted so repeats are no-ops.
- One shared `Orders::Summary` feeds web, checkout preview, offline instructions, HTML and text email, PDF, Factur-X XML and JSON-LD, guarded by `order_summary_surfaces_spec`.
- `AgreementGate` fails closed and is called from checkout, walk-up, subscription and renewal paths; checkout request specs test crafted requests (drafts, inapplicable ticks). Acceptance records are read-only after create (model `readonly?`) and tied to the order's platform at DB level (SEC-11 asks for stronger immutability on the evidence columns).
- 12 of 13 sampled "covered" stories are fully asserted by specs.

UX and i18n
- Real translation parity across four locales for all 867 billing keys with matching interpolation variables; locale-aware currency and date output.
- Good hand-built semantics where present: readiness checklist text, status badges never colour only, credit and subscription tables with captions and `scope="row"`, `role="alert"` error banners, `fieldset`/`legend` groups, `aria-current` breadcrumbs.
- Checkout is progressive (works without JS, Turbo Frame summary refresh, unavailable methods listed with the reason); destructive cancel and waive actions use `turbo_confirm`; the offline-payment disclosure is explicit; walk-up, credit and plan forms already pass axe; emails carry no payment instructions; PDFs are built in the document's own language with structured invoice data attached.

Old branch
- CURRENT already ported and hardened the event pipeline from PR #1581 (idempotency, claim lease, retry backoff, sweep, redaction, encrypted payloads, queue routing, runbook diagram, specs); it is better than OLD on every webhook point.

## 6. Prioritized remediation plan

Effort: S under half a day, M one to three days, L more than three days. "Source" says whether the work is new code or a copy from the old worktree per the batches in 4.5. Findings closed use merged IDs.

### 6.1 Before merge to main

| # | Package | Scope | Closes | Source | Guarding specs | Effort | Depends on |
|---|---|---|---|---|---|---|---|
| M1 | Seeded agreements stay draft (do this first) | Find whether `Seed.import_or_update!` or the agreement builder creates the rows `active` before the `find_or_create_by!` block applies `DRAFT_ATTRIBUTES`; set `lifecycle_state: 'draft'` on every create path. Do not merge with red safety specs. | CONF-11 | New code | The 6 failing specs: `purchase_agreement_seeds_spec.rb:12`, `checkout_spec.rb:43,211,233`, `orders/place_spec.rb:103`, `checkouts_controller_spec.rb:144` | S to M | none |
| M2 | Tax report basis and PDF date zone | Iterate `TaxReport::BASES` with `...additional.bases.#{i}`; apply the resolved document zone in `Document#date`. | UX-07, UX-25 | New code | `spec/dom_contracts/billing_tax_reports_spec.rb` basis select offers exactly paid and invoice with real text; document spec at an offset zone around midnight UTC | S | none |
| M3 | Labels and an axe gate | Pass `for:` matching each custom id on the 15 labels in 5 forms (or drop custom ids); add one `:accessibility, :js` feature spec visiting each billing page (buyer and steward) with `be_axe_clean`, plus a `label[for]` resolver in the dom_contract helper. | UX-17, UX-01, UX-02, UX-22 | New code | The new axe feature spec and the shared dom_contract resolver | S to M | none |
| M4 | Squash billing migrations | Fold `20261114090000_localize_better_together_billing_text` into the create migrations; keep `refuse_foreign_pay_tables!` for hosts that already use Pay; make the Pay `down` refuse when rows exist; check each CE host app schema for pay_* tables. Confirm no staging or review app ran the earlier files. | PERF-03, PERF-08 | New code | Migration spec against a schema with Pay's stock tables; localize spec with a seeded row if kept | S | owner confirms no deployed environment ran the earlier files |

### 6.2 Before first production enablement (host platform only)

| # | Package | Scope | Closes | Source | Guarding specs | Effort | Depends on |
|---|---|---|---|---|---|---|---|
| P1 | Interim host-only fail-closed gate | `manage_billing?` and `setting_context` require `owner.host?` until the hosted agreement gate exists. | CONF-01 (interim half), SEC-10 (interim) | New code | Request spec: non-host steward gets 404 on `/billing/processor_settings` and cannot place an order | S | none |
| P2 | Person and platform scoping | Credit grants use `find_platform_person`; walk-up refuses or invites a non-member and never records acceptance for them. Optionally add the checkout idempotency token (SEC-04) and an upper bound on grants (SEC-13) while in these files. | SEC-01, SEC-05 (and SEC-04, SEC-13 if included) | New code | Request specs: grant to non-member refused and no account; walk-up with non-member email creates no order and no acceptance | S | owner decision on invite vs refuse (section 8) |
| P3 | Invoice Upload ownership | Deny `update?` and `destroy?` in `UploadPolicy` when an `OrderDocument` references the upload, or own it by the platform; verify checksum at download. First confirm the UploadsController parameter whitelist (HYPOTHESIS). | SEC-06 | New code | Policy spec: buyer cannot update an order-document upload | S | none |
| P4 | Throttles and log filtering | Per-IP and per-user throttles for checkout create, walk-up create and seller refunds; invitation cap per steward per day; add buyer name, address, reference, note and payee settings keys to the engine `filter_parameters`. | SEC-07, CONF-07, SEC-09 | New code | Rack::Attack spec (21st request returns 429); `filter_parameters` assertion | S | none |
| P5 | Concurrency, signature and mount specs | One non-transactional `:concurrency` spec each for `Promotions::Redeem` at cap, `Refunds::Record`, `Orders::AddPayment` idempotency key and offline confirm; invalid and missing `Stripe-Signature` request spec; `/pay` mount constraint routing spec; throttle specs for offline claims and order payments; shared cross-tenant example for every billing controller; widen the tenant isolation guard (forbid class-level `find` in controllers, add services and notifiers). | SEC-15, CONF-04, CONF-05, CONF-06 | New code | The new specs themselves | M | none |
| P6 | Operator tooling | Rake tasks `list_events[status]`, `replay_event[id]`, `enqueue_pending`, `orphaned_payments` (reuse `ReplayEvent`); re-enqueue stale `pending` events before dead-lettering; gate replay on an operator policy when a caller is built; document the pause path. This is OLD batch 1 (C-1, C-2): write new, no OLD source exists. Then OLD batch 3: adapt the OLD webhook operations runbook (C-5) into `docs/production/billing_webhook_operations.md`. | PERF-09, SEC-02 | New code (batch 1); copy and adapt (batch 3 runbook) | `spec/tasks/better_together/billing_events_rake_spec.rb` (model on OLD `billing_sponsorships_spec.rb` boilerplate), dead-letter job spec, replay and event specs | M | owner decisions 2, 4 and 7 in section 8 |
| P7 | Billing OFF truly inert | Wrap the Pay mount and `WebhookSubscriptions.subscribe_all!` in `Billing::Configuration.requested?`; make scheduled jobs return early when it is false; document the always-on tables. | PERF-14 | New code (port the idea of gating the new reconcile scan job per OLD C-8 later) | Routing spec: `/pay/webhooks` 404s with flag off | M | none |
| P8 | Money-moving steward UX | `turbo_confirm` with amount and buyer on mark received, record refund, refund to credit, grant credit, reject; hidden order number in queue button names; plan price entered in major units with live preview; show refunds to the buyer; steward navigation group and readiness links to each page; agreement ticks preserved on checkout re-render; keyboard-safe agreement unlock. | UX-13, UX-14, UX-18, UX-16, UX-26, UX-20, UX-21 | New code. Optional: OLD C-3 and C-4 (events alerts partial, events controller and policy) as batch 2 if an operator events page is wanted | `data-turbo-confirm` dom_contract and request specs; plan request spec with "45.00" and "45"; navigation_builder spec; keyboard-only axe feature spec; for batch 2 the events controller, policy and dom contract specs plus screenshots per CE view rules | M to L | M3 (axe gate) |
| P9 | Currency check for vendor processors | Pass `currency:` through `Payments::Succeed` and refuse or flag a mismatch. Needed only when a vendor adapter is enabled. | SEC-12 | New code (the vendor adapter is outside this tree) | Service spec with a mismatched currency | S | vendor adapter work |

### 6.3 Before hosted-platform enablement

| # | Package | Scope | Closes | Source | Guarding specs | Effort | Depends on |
|---|---|---|---|---|---|---|---|
| H1 | Hosted agreement gates (D3a, G22) | Hosted platform billing agreement and hosted local billing agreement: accepted, in-force agreement per platform, enforced in `compute_enabled?` and ProcessorSettings update; host exempt; replaces the interim P1 gate. | CONF-01, SEC-10 (full) | New code | Request spec: non-host steward without acceptance gets 404 on every billing route | M to L | P1; owner agreement text |
| H2 | Pause mechanism | A single `Billing.mode_open?(platform, mode)` consulted by `Orders::Place`, `Orders::AddPayment`, `GenerateRenewal` and offline confirm; withdrawing an agreement pauses without deleting. | CONF-02 | New code | One spec per entry point refusing while paused and keeping rows | L | H1 |
| H3 | Merchant onboarding and own-processor connection (D8, D9) | Correctly unbuilt today; design after H1 and H2. | (none yet) | New code | n/a | L | H1, H2, owner decision 5 in section 8 |
| H4 | Stripe adapter groundwork | Only if a first-party Stripe adapter is in scope (OLD decision 1): OLD batch 4, rows C-6 sanitizer (copy and adapt, fail closed on unknown object type), C-7 handlers (reference only, rewrite to `EventResult`), C-8 reconcile scan (adapt, advisory lock, ordered batches, billing queue). | (reuse opportunity, no finding) | Copy and adapt from the old worktree | Stripe adapter shared examples, sanitizer spec with unknown-object and no-PII cases, reconcile scan job spec | L | Owner decision 1 in section 4.6; P5 signature spec |

### 6.4 Later

| # | Package | Scope | Closes | Source | Guarding specs | Effort | Depends on |
|---|---|---|---|---|---|---|---|
| L1 | Query and index performance | Preload translations and grants on index pages; filter preloaded grants in Ruby; add orders indexes `(platform_id, created_at)`, `(platform_id, paid_at)`, `(platform_id, placed_at)`, `(buyer_id, created_at)`; paginate promotions and tax registrations; fix Summary and grants panel N+1; pre-filter sweeps by due date; index hygiene. | PERF-01, PERF-02, PERF-05, PERF-10, PERF-11, PERF-12, PERF-13 | New code | Query-count specs per index page; index-presence schema spec | M | none |
| L2 | Reports and documents off the request | Cap report span, build report data in the job, throttle report creation; generate PDFs in a job and resolve the quota owner to the platform. | PERF-04, PERF-07 | New code | Over-long span spec; job specs; quota usage after generation | M | none |
| L3 | Lock order discipline | Document and enforce one order (order, payment, credit account) or wrap `AddPayment` in `DeadlockRetry`. | PERF-06, SEC-03 | New code | Two-thread concurrency spec (builds on P5) | M | P5 |
| L4 | Model hardening | Immutable acceptance evidence columns; transition tables and exhaustive transition specs for Refund and SubscriptionPeriod; CSV `safe` on every string cell; platform filter on allowances quotas; rounding specs for multi-line, inclusive and JPY. | SEC-11, CONF-10, SEC-08, SEC-14, CONF-08 | New code | Model, CSV, request and calculator specs as listed in each finding | M | none |
| L5 | Accessibility and i18n remainder | Form error association, live region for summary refresh, link and button names, table captions and headers, breadcrumb key, plurals, `lang` on fallback text, email and PDF accessibility, chart text alternatives, contrast, grant summary translations. | UX-02 remainder, UX-03, UX-04, UX-05, UX-06, UX-08, UX-09, UX-10, UX-11, UX-12, UX-15, UX-19, UX-23, UX-24, UX-28, UX-29, UX-30, UX-31 | New code | dom_contracts per finding; axe spec from M3 extended | M to L | M3 |
| L6 | Journey gaps | Buyer cancel of unpaid order, estimated tax before placing, resend receipt, plan and payment-method change, billing address editor, order filters. | UX-27 | New code | Request and feature specs | L | owner decisions |
| L7 | Documentation drift | Update story doc, isolation doc, ERD (eight missing tables), order lifecycle diagram, roadmap; extend `bin/check_diagrams` to fail on a missing billing table. | CONF-03, CONF-09 | New code | `bin/check_diagrams` | S | none |
| L8 | Cache dependency | Document or move the promotion lockout counter to the DB. | SEC-16 | New code | Spec with null_store | S | none |

## 7. Not checked (merged)

Security
- Pay extension gem (vendor adapters, Stripe signature verification, `Payments::Succeed` callers); not in this tree.
- Runtime behavior: no request specs run by the security reviewer; the UploadsController parameter whitelist (SEC-06) and RangeError handling (SEC-13) are therefore HYPOTHESIS.
- Agreement text rendering and `AgreementAcceptanceRecorder` internals, PDF and XML generation internals (a short look for external entity use is advised), the JS controller, mailer templates beyond recipient logic, subscription renewal and entitlement sync services beyond lock review, OfflinePayment `received_on` backdating.
- Proxy trust for `req.ip` (host-app config; `rack_attack.rb:50` notes the dependence on X-Forwarded-For).
- Policies other than OwnerPolicy, UploadPolicy, BillingReportPolicy and EntitlementPolicy were not read line by line; all controllers' authorize calls were mapped.

Performance and operability
- No dynamic benchmarking, EXPLAIN plans or table-size estimates.
- Migrations outside billing (quota, weather, agent grants, event series) and the CE geography backfill (20261109150100).
- Per-view query counts for tax_registrations, agreement_requirements, offline_payments queue and walk_up_sales were skimmed only.
- Whether any CE host app already has Pay tables (PERF-08) and whether OwnerResolver charges buyer or platform for invoice PDFs (PERF-07); other repos out of scope.
- Document generation render cost, Prawn memory, Factur-X attachments.
- Lock-order analysis covers add_payment, refunds/record, settle, credit spend and reverse only; payments/succeed and subscription renew/advance orderings were not traced.

UX and accessibility
- No browser, specs, axe run or screen reader; contrast and focus findings are partly HYPOTHESIS.
- Not read line by line: plans/show, _snapshot, _grants, subscribers views, tax_registrations/index, allowances/index, the agreement_requirements list part, notifier `_notification.html.erb`, `shared/translated_string_field` partials.
- The agreement modal and view controller were skimmed only (UX-21 is a hypothesis); SlimSelect wrapper and `address_geography` controller not read.
- Receipts gem was not installed on the review host, so PDF font coverage for Ukrainian was not inspected (UX-23).
- Responsive behavior at 320px judged from Bootstrap classes only.

Conformance and tests
- Replay authorization (no caller exists; 6 service specs skimmed only).
- `spec/dom_contracts` and `spec/docs_screenshots` were not run or read in depth (excluded by default tags).
- Whether `Seed.import_or_update!` or the builder produces the active agreements (CONF-11 cause).
- Host-app `filter_parameters` beyond the dummy app (CONF-07).

Old branch
- The OLD part compared file trees and read the cited OLD files; it did not run OLD specs or any copy command (the `cp` and `sed` lines in the copy map are untested).

This merge
- Only four High findings were spot-checked by reading cited lines (UX-07, UX-17 address labels, CONF-01, CONF-11 seed code); no spec was run again.

## 8. Open questions for the owner (merged, deduped)

Migrations and rollout
1. Has any staging or review app run migrations 20261105 to 20261113? Is any CE host app's schema already carrying Pay's own tables (PERF-03, PERF-08)? Squash is the proposed answer either way.
2. When will non-host platforms sell? Until then, is the interim host-only gate (P1) acceptable (CONF-01, SEC-10)?
3. Is the seeded-agreement behaviour in CONF-11 a test setup artifact or real? (Resolved by M1; a decision is only needed if the packet intends some agreements to be active.)

Behaviour decisions raised by findings
4. Walk-up sale for an existing account that is not a member: refuse, or send an invitation and place no order (SEC-05)?
5. Should credit grants have a per-grant ceiling and a daily steward limit, and what values (SEC-13)?
6. Are quotas platform-global by design, or should the allowances screen filter by platform (SEC-14)?
7. Should invoice and receipt Uploads be owned by the platform or system, and should their storage count against the buyer's media quota (SEC-06, PERF-07)?
8. Should a buyer be able to cancel their own unpaid order, and should checkout show an estimated tax before placing (UX-27 a and d)? Is story 1.3 (sign-in mid-checkout loses the selection) stale?
9. Should the plan price form take major units (UX-18)?
10. Do Merchant onboarding, own-processor connection and the pause mechanism (D3a, D8, D9) stay in the hosted milestone as planned (CONF-02)?

Decisions from OLD.md (verbatim)
1. Is a first-party Stripe adapter in scope, or does Stripe stay on Pay's own handlers plus `Pay::Webhook` reprocessing? Batch 4 and every Stripe row depend on this; if Pay-only, C-6 to C-9 become IGNORE.
2. Who may replay events: host-platform steward only, or also each platform's billing manager? (Replay re-runs processor side effects; recommendation: operator only.)
3. Should the events page be per platform (platform manager sees own events) or host-wide? Events are platform-bound, so per platform is natural; host-wide needs a deliberate cross-tenant policy.
4. Add a runtime platform-level billing pause (PERF-09, PERF-14) in the same PR as the events page, or separately?
5. Keep Stripe Connect merchant onboarding and sponsorships/community billing (dropped by CURRENT), or confirm they are out of scope?
6. Sentry: add `Rails.error.report` calls to the sweep rescue and `EventProcessor.fail_with` now (cheap), or wait for the Sentry integration decision?
7. Pending-event re-enqueue interval and whether events stuck `pending` should alert before dead-lettering at 6 hours.

## Remediation status (2026-11-12)

All fixes are draft PRs into `feature/billing`, one per fix. Linked here by PR number only.

| Finding | Outcome | PR |
|---|---|---|
| CONF-11 seeded agreements active | Not a production defect: spec-order pollution. Test guard and re-seed spec added | 2145 |
| Tax report basis select, PDF date time zone | Fixed | 2148 |
| Form labels not tied to inputs, no accessibility gate | Fixed, gate added | 2149 |
| Skipped axe rules (contrast, scroll region, SlimSelect ARIA) | Fixed, skip list removed | 2152 |
| Migration tidy, Pay table guard | Fixed (migrations folded, down refuses populated tables) | 2150 |
| CONF-01 non-host platforms could enable billing | Reproduced, fixed | 2153 |
| SEC-01 credit grants to non-members, no cap | Reproduced, fixed | 2155 |
| SEC-06 buyer could rename invoice files | Partly reproduced (rename yes; public rejected; delete already refused), fixed | 2156 |
| SEC-07 rate limits, SEC-09 PII in logs | Fixed | 2157 |
| SEC-05 walk-up binds non-member accounts | Reproduced, fixed (guest buyer, invitation cap) | 2159 |
| SEC-15 safety-net tests | Added (valid-signature acceptance not testable without a processor gem) | 2161 |
| PERF-14 billing-off not inert | Four leaks reproduced and fixed | 2162 |
| PERF-09 operator tooling for failed events | Built (rake tasks, sweep, page, runbook) | 2163 |
| Steward UX: confirmations, prices, buyer refunds | Fixed | 2164 |
| Steward UX: navigation, kept ticks, keyboard reader | Fixed | 2166 |

Postponed (Step 4): list-page performance and indexes, moving reports and PDFs off the web request, consistent lock order, remaining data-model checks, buyer features (cancel unpaid order, tax preview, resend receipt), stale docs and diagrams. Step 3 (hosted selling) is separate.

Known leftovers: `billing_plans_new_create` screenshot not regenerated; the walk-up and SlimSelect/hub changes will conflict slightly in the hub view; uk translations unreviewed; no signature-verification test without a processor gem.
