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
- Snippets tagged analytics or marketing are not rendered until the visitor consents (consent support lands with the consent banner).
- Inline code cannot contain script or style closing tags or HTML comments; size is limited to 20,000 characters. Isolation relies on the CSP, not on sanitizing code, so only grant the role to people you trust with your visitors' sessions.
