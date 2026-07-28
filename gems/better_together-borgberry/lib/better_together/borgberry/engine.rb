# frozen_string_literal: true

module BetterTogether
  module Borgberry
    # Boots the optional C3 Tree Seeds + Borgberry fleet extension inside a CE host app.
    # Follows the same nested-gem pattern the (now externally hosted)
    # better_together-elasticsearch extension used: core CE carries no direct
    # knowledge of C3/Fleet — this engine reaches in once bundled, via:
    #   - ModelRegistry#apply_model_decorations! (Person/PlatformConnection/JoatuAgreement)
    #   - BetterTogether.api_v1_routes_extension (namespace :c3 / :borgberry / :fleet)
    #   - BetterTogether::FederationScopeAuthorizer.register_scope_rule('c3.exchange')
    #   - Joatu::AgreementsController.rescue_from(C3::Balance::InsufficientBalance)
    class Engine < ::Rails::Engine
      engine_name 'better_together_borgberry'

      # NOTE: this gem's own spec/factories/ directory is registered with
      # FactoryBot from the HOST app's spec/rails_helper.rb, not from this
      # engine — doing it here via config.to_prepare caused a FrozenError on
      # the app's middleware stack (adding to_prepare/initializer entries here
      # shifted core CE's own initializer ordering enough to run its
      # `app.middleware.use` call after the stack had already been built and
      # frozen). Test-only config belongs in the test suite's own setup, not
      # engine boot code that also runs in production.

      initializer 'better_together_borgberry.model_decorations' do
        BetterTogether::Borgberry::ModelRegistry.register_default_decorations!

        config.to_prepare do
          BetterTogether::Borgberry::ModelRegistry.apply_model_decorations!
        end
      end

      # NOTE: for host apps that already set BetterTogether.api_v1_routes_extension
      # of their own: this chains onto whatever was set before this initializer
      # runs. If your host app's OWN initializer runs later (e.g. from
      # config/initializers/*.rb, which loads after engine initializers), it
      # must chain onto the existing value itself rather than reassigning, or
      # it will silently drop these routes. See README.md for the composable
      # registration pattern host apps should follow with multiple extensions.
      initializer 'better_together_borgberry.api_v1_routes' do
        existing_extension = BetterTogether.api_v1_routes_extension
        BetterTogether.api_v1_routes_extension = proc do
          instance_exec(&existing_extension) if existing_extension

          namespace :c3 do
            post 'contributions',   to: 'contributions#create'
            get  'contributions',   to: 'contributions#index'
            get  'balance',         to: 'contributions#balance'
            get  'network_balance', to: 'contributions#network_balance'
          end

          namespace :borgberry do
            get 'profile', to: 'profile#show'
          end

          namespace :fleet do
            resources :nodes, param: :node_id, only: %i[index show create] do
              member do
                post :heartbeat
              end
            end
          end
        end
      end

      initializer 'better_together_borgberry.federation_routes' do
        existing_extension = BetterTogether.federation_routes_extension
        BetterTogether.federation_routes_extension = proc do
          instance_exec(&existing_extension) if existing_extension

          # C3 cross-platform settlement endpoints (authenticated via FederationAccessToken scope: c3.exchange)
          post 'c3/token_seeds',   to: 'c3_token_seeds#create',   as: :c3_token_seed
          post 'c3/lock_requests', to: 'c3_lock_requests#create', as: :c3_lock_request
        end
      end

      config.to_prepare do
        BetterTogether::FederationScopeAuthorizer.register_scope_rule('c3.exchange', &:allows_c3_exchange?)
      end

      config.to_prepare do
        controller = BetterTogether::Joatu::AgreementsController
        # to_prepare can fire repeatedly under dev code reloading; rescue_from has
        # no built-in idempotency, so guard against piling up duplicate handlers.
        already_registered = controller.rescue_handlers.any? do |klass_name, _|
          klass_name == BetterTogether::C3::Balance::InsufficientBalance.name
        end

        unless already_registered
          controller.rescue_from(BetterTogether::C3::Balance::InsufficientBalance) do
            redirect_to joatu_agreement_path(@joatu_agreement),
                        alert: BetterTogether::Joatu::InsufficientC3AlertBuilder.call(@joatu_agreement, self)
          end
        end
      end
    end
  end
end
