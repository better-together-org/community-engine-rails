# frozen_string_literal: true

# bt base path
# rubocop:disable Metrics/BlockLength
scope path: BetterTogether.route_scope_path do
  # API Authentication routes (no locale requirement)
  # These routes handle JWT token generation and don't need localization
  namespace :api do
    # OAuth2 endpoints (Doorkeeper): /api/oauth/token, /api/oauth/authorize, /api/oauth/revoke.
    use_doorkeeper do
      # Skip Doorkeeper's application-management UIs; we use our own application management.
      # Keep `:authorizations` enabled to support the authorization_code grant flow.
      skip_controllers :applications, :authorized_applications
    end

    defaults format: :json do
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

      # OAuth application management (custom controller)
      resources :oauth_applications, controller: 'oauth/applications',
                                     only: %i[index show create update destroy]

      # Version 1 JSON API endpoints (resources, collections, etc.)
      draw :api_v1

      # API documentation endpoints (e.g., OpenAPI / Swagger UI)
      draw :api_docs
    end
  end
end
# rubocop:enable Metrics/BlockLength
