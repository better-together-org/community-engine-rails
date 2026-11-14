# Cookie Consent And Cookie Policy Extensions

How Community Engine records cookie consent, and how gems and host apps declare the cookies they use so the cookie policy page and the consent settings describe them automatically.

## What a visitor and a signed-in person get

- A visitor who decides in the consent banner gets a `bt_consent` cookie (JSON, `{"v":1,"analytics":bool,"marketing":bool,"pv":"<policy version>"}`). Nothing is stored on the server for an anonymous visitor.
- A signed-in person's decision is also stored on their record, in the existing `people.preferences` JSON under `cookie_consent` (`analytics`, `marketing`, `decided_at`, `policy_version`). There is no new table. `BetterTogether::ConsentPreference` reads and writes it.
- The banner, and the **Cookie consent** tab in Settings, save through `PATCH /:locale/settings/cookie_consent` (`CookieConsentsController`). The route needs a signed-in person, is CSRF protected, authorizes only the person's own record (`CookieConsentPolicy`), and accepts only `consent[analytics]` and `consent[marketing]`. The server sets the date and policy version; a category that is not clearly affirmative (`1`, `true`, `on`) counts as declined.

## Signed-in precedence rules

On every GET while signed in (`ConsentCookieSync`), the stored decision is the source of truth:

| Stored decision (current policy version) | Cookie | What happens |
| --- | --- | --- |
| yes | missing or different | the cookie is rewritten from the stored decision |
| yes | same | the cookie is rewritten anyway, which refreshes its 180 day expiry |
| no (none, or an older policy version) | current decision made as a visitor | the cookie decision is adopted into the person's record |
| no | none, or an older policy version | nothing; the banner asks |

So when a visitor decides anonymously and then signs in, a person with no stored decision keeps what they chose; a person who already has a stored decision gets that decision on this browser. Signing out leaves the cookie as it is. The cookie is written with `Path=/`, `SameSite=Lax`, `Secure` over https or in production, a 180 day expiry and no `HttpOnly` (the banner script and consent mode code read it). The sync runs in the same request before the page renders, so server-side gating of snippets and the banner agree with the stored decision with no flash.

## Consent policy version

`BetterTogether::Consent.policy_version(platform)` is a short hash of the registered consent providers (and the categories each uses) plus the non-essential cookie policy segments visible on the platform. It is stored with every decision and written in the cookie as `pv`. When it changes, for example a gem starts to use marketing cookies, older decisions are treated as undecided and the banner asks again. Adding an essential segment does not change it.

## Registering a consent provider

A provider tells Community Engine that code on this platform needs consent. Return the categories it uses so the banner and the settings form list only those:

```ruby
BetterTogether.register_consent_provider(:google_analytics) do |platform|
  next false unless measurement_id_present?(platform) # no consent needed
  :analytics                                           # or %i[analytics marketing], or true for both
end
```

`false`/`nil` means nothing to ask. `true` means every category. A provider that raises counts as using every category, so a bug never skips the banner.

## Registering a cookie policy segment

```ruby
BetterTogether.register_cookie_policy_segment(
  key,                         # Symbol, unique; registering the same key again replaces it
  category:,                   # :essential, :analytics or :marketing
  title:,                      # literal, i18n key (dotted), Symbol or ->(platform) { ... }
  description: nil,            # same forms as title
  cookies: [],                 # Array of hashes, or ->(platform) { [...] }
  privacy_url: nil,            # provider privacy page, shown as a link
  updated_on: nil,             # Date; the policy "Last updated" is the newest of these and the core date
  if: nil                      # ->(platform) { true/false }; hidden when false
)
```

Each cookie hash: `{ name:, purpose:, duration:, provider:, party: :first | :third }` (`purpose`, `duration` and `provider` take the same forms as `title`). Use the same entry for browser storage; say so in `purpose`. A failing `if:` keeps the segment visible (disclosing too much is safer than hiding a cookie); a failing `cookies:` callable lists no cookies.

Community Engine registers its own essential segments (`:session`, `:consent`).

### Example: the Google Analytics gem

```ruby
module BetterTogether
  module GoogleAnalytics
    def self.register_consent!
      BetterTogether.register_consent_provider(:google_analytics) do |platform|
        HeadTags.consent_needed?(platform) ? :analytics : false
      end

      BetterTogether.register_cookie_policy_segment(
        :google_analytics,
        category: :analytics,
        title: 'Google Analytics',
        description: 'Counts visits and which pages are read so we can improve the site.',
        cookies: [
          { name: '_ga', purpose: 'Tells one visitor from another', duration: '2 years',
            provider: 'Google', party: :third },
          { name: '_ga_<container-id>', purpose: 'Keeps session state', duration: '2 years',
            provider: 'Google', party: :third }
        ],
        privacy_url: 'https://policies.google.com/privacy',
        updated_on: Date.new(2026, 11, 14),
        if: ->(platform) { HeadTags.measurement_id(platform).present? }
      )
    end
  end
end
```

The segment appears only on platforms that have a measurement id, so one gem install serves every platform correctly.

### Example: a host app

```ruby
# config/initializers/cookie_policy.rb
Rails.application.config.after_initialize do
  BetterTogether.register_cookie_policy_segment(
    :newsletter_referrer,
    category: :marketing,
    title: 'host_app.cookies.newsletter.title',        # keys in the host's own locale files
    description: 'host_app.cookies.newsletter.description',
    cookies: [{ name: 'nl_ref', purpose: 'host_app.cookies.newsletter.purpose',
                duration: '30 days', party: :first }]
  )
  BetterTogether.register_consent_provider(:newsletter_referrer) { :marketing }
end
```

For prose that does not fit a table, add `app/views/better_together/cookie_policy/_host_additions.html.erb` to the host app. The cookie policy page renders it after the optional cookies section.

## What renders where

- **Cookie policy page** (`better_together/static_pages/cookie_consent`): essential segments in section 4, optional segments grouped by category in section 5, a "Last updated" date and policy version derived from the registry. With no extensions there are no optional headings and the default "no optional cookies" text stays.
- **Settings, Cookie consent tab**: Essential (always on) plus one switch for each category something on the platform uses (providers, visible segments, enabled snippets). Each switch lists the segments in that category. Saving or "Withdraw all optional consent" updates the record and cookie and fires the `better_together:consent` window event, so consent mode code reacts without a reload.
- **Consent banner**: lists the same categories.

## Testing a segment in a gem

```ruby
require 'better_together/cookie_policy/rspec'

RSpec.describe 'GA cookie policy' do
  include_context 'with an isolated cookie policy registry'
  let(:platform) { BetterTogether::Platform.new(name: 'Test') }
  before { BetterTogether::GoogleAnalytics.register_consent! }

  it_behaves_like 'a cookie policy segment', :google_analytics, category: 'analytics'
end
```

The shared example checks the segment is visible for `platform`, has a title and description, describes every cookie completely (provider and privacy link for third-party cookies) and counts toward the consent categories. `BetterTogether::Consent.reset!` also clears both registries (and re-registers the core segments).
