# Multi-hostname testing

One app instance and one port serve every hostname, as in production. Tests do not start several servers, and a platform's own URL carries no port.

- **Request specs:** `create_platform_on_hostname('club.mds.test')` makes a platform with a primary domain. `on_hostname('club.mds.test') { |platform| ... }` sets the request `Host` and `Current.platform` for the block.
- **Mailer and job specs:** use `on_hostname` (or `Current.set(platform:)`) around the code that queues or renders. Jobs carry the platform (MDS-1) and mail links use the primary domain (MDS-1 to MDS-3).
- **Browser specs:** tag the example `:js, :multi_host`. The `:selenium_chrome_headless_multi_host` driver maps `*.mds.test` to `127.0.0.1`; the port stays in the URL, so every hostname reaches the one Capybara server. Build URLs with `multi_host_url(hostname, path)`. Other drivers carry no resolver rule.
- **Host domain rows:** the `:deletion` cleanup of JS, feature and system examples empties the platform domains table. `HostDomainHealing` snapshots the host platform's domain rows before such an example and restores them afterwards, so later examples still resolve the host.
- Secondary domains redirect to the primary (MDS-3). Specs that serve an alias domain set `redirect_secondary_domains: false` on the platform.

Support code: `spec/support/multi_hostname_helpers.rb`. Examples: `spec/requests/better_together/multi_hostname_support_spec.rb`, `spec/features/better_together/multi_host_browser_spec.rb`.
