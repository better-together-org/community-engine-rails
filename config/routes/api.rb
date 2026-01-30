# frozen_string_literal: true

# bt base path
scope path: BetterTogether.route_scope_path do
  # API Authentication routes (no locale requirement)
  # These routes handle JWT token generation and don't need localization
  namespace :api, defaults: { format: :json } do
    devise_for :users,
               class_name: BetterTogether.user_class.to_s,
               skip: %i[unlocks omniauth_callbacks],
               path: 'auth',
               path_names: {
                 sign_in: 'sign-in',
                 sign_out: 'sign-out',
                 registration: 'sign-up'
               },
               controllers: {
                 sessions: 'better_together/api/auth/sessions',
                 registrations: 'better_together/api/auth/registrations',
                 passwords: 'better_together/api/auth/passwords',
                 confirmations: 'better_together/api/auth/confirmations'
               }

    draw :api_v1
    draw :api_docs
  end
end
