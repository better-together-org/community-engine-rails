# Custom code snippets

Platform custom code lets a trusted steward add scripts, styles and meta tags to every page, like the header and footer scripts of a WordPress site. Open the Integrations tab of the platform form and choose Manage custom code.

## Who can use it

Only people holding `manage_platform_code`, through the Platform Code Manager role granted on that platform. Platform stewards and managers do not hold it by default, so a hosted tenant never gets it unless the host steward grants the role explicitly. Adding a script origin to the platform content security policy also needs `manage_platform_security`.

## Locations and kinds

- Locations: start of head, end of head, start of body, end of body.
- Kinds: inline script (runs with the per-request CSP nonce), external script (https address; the origin must be on the platform's script allow-list), inline style, meta tags (meta tags and preconnect, dns-prefetch, canonical, alternate and me links only; head only).
- Snippets are ordered per location; Up and Down swap neighbours.

## Guard rails

- New snippets start disabled. Imported snippets also arrive disabled and wait for review.
- Every create, update, enable, disable and delete is audited with the actor and the change.
- Safe mode: add `?safe_mode=1` to any page address as a person who manages code to view the page without snippets. The Switch all off button is a platform-wide kill switch.
- A snippet that fails to render is logged and skipped; it never breaks the page.
- An external script stops loading as soon as its origin leaves the allow-list.
- Snippets tagged analytics or marketing are held until the visitor consents to that category. See Visitor consent below.
- Inline code cannot contain script or style closing tags or HTML comments; size is limited to 20,000 characters. Isolation relies on the CSP, not on sanitizing code, so only grant the role to people you trust with your visitors' sessions.

## Visitor consent

When a platform has an enabled analytics or marketing snippet, or an extension (such as the Google Analytics gem with "wait for visitor consent" on) asks for consent, the layout shows a consent banner:

- Buttons: Accept all, Essential only, and Choose (analytics and marketing checkboxes with Save).
- The decision is stored in the `bt_consent` cookie (180 days, `SameSite=Lax`) as `{"v":1,"analytics":bool,"marketing":bool}`. Only a literal `true` counts as consent.
- Held snippets render on the next page load once the category is granted. Choosing reloads the page when held snippets exist.
- A "Cookie preferences" button (`#consent-preferences-link`) stays on the page after a decision so visitors can change it. The banner links to the platform's Cookie Policy page when it exists.
- The browser event `better_together:consent` (detail `{analytics, marketing}`) fires on every decision and on each page load with a stored decision. Extensions use it for Google consent mode v2.
- Extension gems register `BetterTogether.register_consent_provider(:key) { |platform| false_or_categories }` (see [Cookie consent extensions](../developers/systems/cookie_consent_extensions.md)). A provider that raises is treated as "consent needed".
- Signed-in people have their decision stored on their account and applied on every visit; they can change it in Settings under Cookie consent. See Cookie consent for signed-in people below.
- The banner is not a modal. Targets are at least 44px and focus moves to the first checkbox when choices open.

## Cookie consent for signed-in people

- A signed-in person's choice is saved to their account (inside their preferences, no extra data store) and the `bt_consent` cookie is rewritten from it on every visit, which also refreshes its expiry. The stored choice wins over the cookie in the browser.
- If a visitor chose before signing in and the person has no stored choice yet, the visitor's choice is adopted at sign-in. Signing out leaves the cookie as it is.
- People change their choice in Settings, Cookie consent: one switch for each category the platform uses, Essential always on, and Withdraw all optional consent.
- When the platform starts using a new category (for example a new analytics extension is installed) everyone is asked again.

## The cookie policy page

The Cookie Policy page lists the cookies Community Engine uses and, automatically, the cookies and storage that extensions and your host app declare, grouped by category with a last updated date. To add your own wording, ask your developer to add the host additions partial described in [Cookie consent extensions](../developers/systems/cookie_consent_extensions.md). You do not need to edit the page text when you install an extension that declares its cookies.

Not covered yet: the banner is in the main application layout only, not the conversation or Turbo Native layouts.
