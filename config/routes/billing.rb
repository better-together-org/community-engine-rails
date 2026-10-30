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

# What a billing owner can manage. Declared as a concern so a community-scoped mount
# (`resources :communities, only: [] { concerns :billing_plans }`) can reuse it later.
# Not nested under the host dashboard and carrying no route-level permission check:
# access is sign-in plus Pundit on the billing owner (see Billing::OwnerScoped).
concern :billing_plans do
  namespace :billing do
    resources :plans, except: :destroy do
      member do
        post :sync
        get :snapshot
      end
    end
    resources :processor_options, only: :index
    resources :processor_settings, only: %i[index edit update]
    resources :orders, only: %i[index show]
    resources :sales, only: %i[index show]
  end
end

# Same locale and base-path scopes as the localized block in routes.rb.
scope ':locale', locale: /#{I18n.available_locales.join('|')}/ do
  scope path: BetterTogether.route_scope_path do
    concerns :billing_plans
  end
end
