# frozen_string_literal: true

require 'sidekiq/web'

BetterTogether::Engine.routes.draw do # rubocop:todo Metrics/BlockLength
  scope ':locale', # rubocop:todo Metrics/BlockLength
        locale: /#{I18n.available_locales.join('|')}/ do
    # bt base path
    scope path: BetterTogether.route_scope_path do # rubocop:todo Metrics/BlockLength
      # Aug 2nd 2024: Inherit from blank devise controllers to fix issue generating locale paths for devise
      # https://github.com/heartcombo/devise/issues/4282#issuecomment-259706108
      # Uncomment omniauth_callbacks and unlocks if/when used
      devise_for :users,
                 class_name: BetterTogether.user_class.to_s,
                 controllers: {
                   confirmations: 'better_together/users/confirmations',
                   #  omniauth_callbacks: 'better_together/users/omniauth_callbacks',
                   passwords: 'better_together/users/passwords',
                   registrations: 'better_together/users/registrations',
                   sessions: 'better_together/users/sessions'
                   #  unlocks: 'better_together/users/unlocks'
                 },
                 module: 'devise',
                 skip: %i[unlocks omniauth_callbacks],
                 path: 'users',
                 path_names: {
                   sign_in: 'sign-in',
                   sign_out: 'sign-out',
                   sign_up: 'sign-up'
                 },
                 defaults: { format: :html, locale: I18n.locale }

      get 'search', to: 'search#search'
      authenticated :user do # rubocop:todo Metrics/BlockLength
        resources :communities, only: %i[index show edit update]
        resources :conversations, only: %i[index new create show] do
          resources :messages, only: %i[index new create]
        end

        resources :notifications, only: %i[index] do
          member do
            post :mark_as_read
          end

          collection do
            post :mark_all_as_read, to: 'notifications#mark_as_read'
          end
        end

        resources :people, only: %i[update show edit], path: :p do
          get 'me', to: 'people#show', as: 'my_profile'
          get 'me/edit', to: 'people#edit', as: 'edit_my_profile'
        end

        authenticated :user, ->(u) { u.permitted_to?('manage_platform') } do # rubocop:todo Metrics/BlockLength
          scope path: 'host' do # rubocop:todo Metrics/BlockLength
            # Add route for the host dashboard
            get '/', to: 'host_dashboard#index', as: 'host_dashboard'

            resources :communities do
              resources :person_community_memberships, only: %i[create destroy]
            end

            namespace :content do
              resources :blocks
            end

            resources :navigation_areas do
              resources :navigation_items
            end

            resources :resource_permissions
            resources :roles

            resources :pages do
              scope module: 'content' do
                resources :page_blocks, only: %i[new destroy], defaults: { format: :turbo_stream }
              end
            end
            resources :people
            resources :person_community_memberships
            resources :platforms, only: %i[index show edit update] do
              resources :platform_invitations, only: %i[create destroy] do
                member do
                  put :resend
                end
              end
            end
            resources :users

            namespace :geography do
              resources :continents, except: %i[new create destroy]
              resources :countries
              resources :regions
              resources :region_settlements
              resources :settlements
              resources :states
            end
          end
        end
      end

      namespace :metrics do
        resources :shares, only: [:create]
        # Add other metrics routes here, e.g., link_clicks, page_views, etc.
      end

      resources :wizards, only: [:show] do
        # Custom route for wizard steps
        get ':wizard_step_definition_id', to: 'wizard_steps#show', as: :step
        patch ':wizard_step_definition_id', to: 'wizard_steps#update'
        # Add other HTTP methbetter-together/community-engine-rails/app/controllers/better_together/bt
      end

      scope path: :w do
        scope path: :setup_wizard do
          get '/', to: 'setup_wizard#show', defaults: { wizard_id: 'host_setup' }, as: :setup_wizard
          get 'platform_details', to: 'setup_wizard_steps#platform_details',
                                  defaults: { wizard_id: 'host_setup', wizard_step_definition_id: :platform_details },
                                  as: :setup_wizard_step_platform_details
          post 'create_host_platform', to: 'setup_wizard_steps#create_host_platform',
                                       defaults: {
                                         wizard_id: 'host_setup',
                                         wizard_step_definition_id: :platform_details
                                       },
                                       as: :setup_wizard_step_create_host_platform
          get 'admin_creation', to: 'setup_wizard_steps#admin_creation',
                                defaults: { wizard_id: 'host_setup', wizard_step_definition_id: :admin_creation },
                                as: :setup_wizard_step_admin_creation
          post 'create_admin', to: 'setup_wizard_steps#create_admin',
                               defaults: { wizard_id: 'host_setup', wizard_step_definition_id: :admin_creation },
                               as: :setup_wizard_step_create_admin
        end
      end
    end

    if Rails.env.development?
      get '/404', to: 'application#render_404'
      get '/500', to: 'application#render_500'
    end

    # Catch-all route
    get '*path', to: 'pages#show', as: 'render_page', constraints: lambda { |req|
      !req.xhr? && req.format.html?
    }

    get 'bt' => 'static_pages#community_engine', as: :community_engine
    get '', to: 'pages#show', defaults: { path: 'home-page' }, as: :home_page
  end

  # Only allow authenticated users to get access
  # to the Sidekiq web interface
  devise_scope :user do
    authenticated :user, ->(u) { u&.person&.permitted_to?('manage_platform') } do
      mount Sidekiq::Web => '/sidekiq'
    end
  end

  # Catch all requests without a locale and redirect to the default...
  get '*path',
      to: redirect { |params, _request| "/#{I18n.locale}/#{params[:path]}" },
      constraints: lambda { |req|
        # raise 'error'
        !req.path.starts_with? "/#{I18n.locale}" and
          !req.path.starts_with? '/rails'
      }
  get '', to: redirect("/#{I18n.default_locale}")
end
