# Third-party tracking exclusions

Analytics, session replay and ad scripts send page addresses and behaviour to outside vendors. Community Engine decides, per request, whether a page may be measured, and extension gems must ask before emitting vendor scripts.

## Default rule: closed unless plainly public

A page is excluded when any of these is true:

| Reason | Meaning |
|--------|---------|
| `explicit` | The controller called `skip_third_party_tracking`. Applied to conversations, messages, message requests, notifications, settings, the host dashboard and every Devise (sign-in, registration, password, confirmation) controller. |
| `not_a_read` | Anything other than GET or HEAD, for example a form re-rendered after a failed submit. |
| `error_response` | Any non-2xx response. An unauthorised or missing record still has its address in the URL. |
| `private_platform` | The host platform itself is not public. |
| `sensitive_params` | The URL carries a token or code (`invitation_code`, `token`, `reset_password_token`, `confirmation_token`, `unlock_token`, `access_token`, `code`, `state`). |
| `private_record` | The page's primary record (`@resource`) is not public, or a signed-in person is on a page with no public primary record (dashboards, settings, lists that may mix community and private items). |
| a registered key | An extension or host app rule (below). |

An anonymous visitor can only see public content, so anonymous pages are allowed unless another rule applies. If evaluating a rule raises, the page is excluded.

## For controllers

```ruby
class MyPrivateController < BetterTogether::ApplicationController
  skip_third_party_tracking                 # all actions
  skip_third_party_tracking only: :show     # before_action options work
end
```

## For extensions and host apps

```ruby
# Exclude a request for your own reason. The block gets the controller; true excludes.
BetterTogether.register_third_party_tracking_exclusion(:members_area) do |controller|
  controller.request.path.start_with?('/members')
end
```

Vendor gems ask the view helper before rendering:

```ruby
BetterTogether.register_head_tag_provider(:my_vendor) do |view_context|
  next unless view_context.third_party_tracking_allowed?

  # render the vendor script
end
```

`third_party_tracking_allowed?` returns true on controllers outside the engine base class. On engines older than this change the helper does not exist, so a gem that must support them should check `view_context.respond_to?(:third_party_tracking_allowed?)` first and treat a missing helper as allowed.

## Scripts that stay loaded across Turbo visits

Head scripts survive Turbo navigation, so a vendor script loaded on a public page could still observe the next, private page. Every layout therefore emits `<meta name="bt-third-party-tracking" content="on|off">`. Scripts must read it on each `turbo:load` and stop reporting when it is `off`.

## Not covered

Server-side error reporting (such as Sentry) is not a measurement vendor in this sense and is not gated by this rule.
