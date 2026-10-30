# frozen_string_literal: true

# Billing routes, loaded from config/routes.rb with `draw :billing` (the same way
# `draw :api` loads config/routes/api.rb). Every billing route lives here: the Pay
# engine mount and the Community Engine billing routes.
#
# This file is drawn just BEFORE the localized `scope ':locale'` block in
# routes.rb, not after it: that block ends in a catch-all
# `get '*path', to: 'pages#show'` for HTML, so billing HTML routes drawn after it
# would never be reached.

# Processor webhooks. Not localized and not behind sign-in: the processor calls
# this endpoint, and Pay verifies the request signature.
#
# Mounted only when a processor gem is installed (Pay draws its webhook routes
# only then, so without one there is nothing to receive). And only the webhook
# endpoints are reachable: Pay's engine also serves GET /payments/:id, an
# unauthenticated page that calls the processor API with the host's key for a
# caller-supplied id. Community Engine's checkout is processor-hosted and does not
# use that page, so it stays closed until a feature needs it.
if [Pay::Stripe, Pay::Braintree, Pay::PaddleBilling, Pay::PaddleClassic, Pay::LemonSqueezy].any?(&:enabled?)
  mount Pay::Engine, at: '/pay', constraints: ->(request) { request.path_info.start_with?('/pay/webhooks/') }
end
