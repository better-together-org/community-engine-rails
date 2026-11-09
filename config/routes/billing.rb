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
# use that page, so it stays closed until a feature needs it (buyers are sent to
# billing/orders/:id/pay instead, which is signed in and checks the order).
#
# The constraint sees the path AFTER the mount point: a mounted app's `path_info` is
# rewritten to the remainder before constraints run, so '/pay/webhooks/stripe' arrives
# as '/webhooks/stripe'. Testing for '/pay/webhooks/' here would 404 every webhook.
if [Pay::Stripe, Pay::Braintree, Pay::PaddleBilling, Pay::PaddleClassic, Pay::LemonSqueezy].any?(&:enabled?)
  mount Pay::Engine, at: '/pay', constraints: ->(request) { request.path_info.start_with?('/webhooks/') }
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
    resources :orders, only: %i[index show] do
      member do
        # Send the buyer to pay through a processor, and take them back (signed in, checked against the order).
        post :pay
        get :checkout_return
      end
      # The buyer says they sent a payment made outside the platform. Optional: the seller can confirm without it.
      resource :claim, only: :create, controller: 'order_claims'
      # The buyer adds a payment (the rest, or a part, by any way of paying) to an order that is not fully paid.
      resources :payments, only: :create, controller: 'order_payments'
    end
    resource :checkout, only: %i[new create]
    resources :agreement_requirements, only: %i[index create destroy]
    resources :sales, only: %i[index show] do
      # Return what was paid toward a sale that will not be completed, then cancel it.
      post :return_payments, on: :member
      post :cancel, on: :member
      # The seller records that they gave money back for a payment made outside the platform.
      resource :refund, only: :create, controller: 'sale_refunds'
    end
  end
end

# Store credit: a person's own credit and promotion codes, and what a steward can see, give and make.
concern :billing_credit do
  namespace :billing do
    # A person's own store credit, and what a steward can see and give.
    resource :credit, only: :show, controller: 'credits'
    # The person select on the steward screen searches here (before :id so it is not read as one).
    get 'credit_accounts/people', to: 'credit_accounts#people', as: :people_credit_accounts
    resources :credit_accounts, only: %i[index show]
    resources :credit_grants, only: :create
    # A person redeems a promotion code; a steward makes and switches them.
    resources :promotion_redemptions, only: :create
    resources :promotions, only: %i[index new create] do
      member do
        patch :activate
        patch :deactivate
      end
    end
  end
end

# Subscriptions Community Engine renews: a payer's own, and the platform's subscribers for stewards.
concern :billing_subscriptions do
  namespace :billing do
    resources :subscriptions, only: %i[index show] do
      member do
        patch :cancel
        patch :resume
        post :accept_agreements
      end
    end
    resources :subscribers, only: %i[index show] do
      member do
        patch :waive
        patch :extend_grace
        patch :cancel
        patch :move_to_current_price
      end
    end
  end
end

# What a paid plan gives: a steward's list of what a plan includes and the platform's allowances, and a person's own access.
concern :billing_entitlements do
  namespace :billing do
    resources :entitlements, only: :index
    resources :allowances, only: %i[index update]
    resources :plans, only: [] do
      resources :plan_grants, only: %i[create destroy]
    end
  end
end

# What a seller has to do about payments made outside the platform (cash, cheque, e-transfer).
concern :billing_offline_payments do
  namespace :billing do
    resources :offline_payments, only: :index do
      member do
        patch :receive
        patch :reject
        patch :clear
        patch :bounce
      end
    end
    resource :walk_up_sale, only: %i[new create]
  end
end

# Same locale and base-path scopes as the localized block in routes.rb.
scope ':locale', locale: /#{I18n.available_locales.join('|')}/ do
  scope path: BetterTogether.route_scope_path do
    concerns :billing_plans, :billing_offline_payments, :billing_credit, :billing_subscriptions, :billing_entitlements
  end
end
