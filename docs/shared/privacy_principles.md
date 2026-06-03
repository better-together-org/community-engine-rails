# Privacy‑First Principles

The Community Engine is designed with privacy as a first principle. Features, defaults, and data flows prioritize the minimum data necessary to deliver value to communities, while leaving room for hosts to layer in additional tooling in line with their own policies and consent practices.

## Defaults: Private by Design
- Access control: Role‑based access (RBAC) determines who can see or do what. Content and management areas are accessible only to permitted members.
- Registration: Platforms are configured by default to require an invitation code (see Accounts & Invitations). Hosts can relax this, but the default is invite‑only.
- Content visibility: Pages and other covered content surfaces respect privacy level (`public`, `community`, `private`) and publication status where applicable. Community-scoped content is visible to signed-in people; unpublished or private content still requires stronger access.

## Metrics: Event‑Only, Not Identity
- We record what happened, not who did it. Metrics events do not store user identifiers.
- Page views capture only: what was viewed (pageable type/id or path), when (timestamp), and locale. Query strings are sanitized to remove sensitive parameters; only the path is stored.
- Link clicks capture: the clicked URL, referring page path, whether it was internal/external, timestamp, and locale.
- Shares capture: which platform, which URL, optional shareable type/id, timestamp, and locale.
- Downloads capture: the filename/content type/size of exported reports, timestamp, and locale.
- Search queries capture: the query string, count of results, timestamp, and locale.

## Federation: Disabled by Default, Scoped When Enabled
- Federation is a platform-to-platform trust feature, not a background default.
- Cross-platform sharing should stay disabled until the participating platforms have agreed on what content and scopes are permitted.
- Current federation controls are primarily operator-managed through `PlatformConnection` policies and scopes.
- Until person-level federation consent is fully implemented, production hosts should treat federation activation as a high-trust, fail-closed decision.

## No Third‑Party Tracking by Default
- By default, the platform ships without Google Analytics or similar trackers. Error reporting is kept minimal and server‑side.
- Platform Managers may integrate additional tooling (e.g., Google Analytics, Sentry, Hotjar) per their own privacy policy and consent framework. Hosts are responsible for:
  - Updating privacy notices and cookie banners.
  - Obtaining consent where required.
  - Configuring data retention and IP anonymization as applicable.

## Data Minimization & Retention
- Collect only attributes necessary for aggregate insights (counts, trends, breakdowns by locale/page).
- Avoid PII in metrics and logs. Strip/sanitize sensitive query parameters.
- Use exportable, human‑readable report formats (CSV) and allow hosts to purge historical exports.

## Transparency & Control
- Make privacy‑relevant settings explicit in admin UIs (e.g., invite‑only, page privacy, metrics/report exports).
- Keep documentation clear about what is captured and why; give maintainers predictable knobs to disable or scope features.
- Document any federation relationship in operator runbooks so communities understand what may cross platform boundaries.
