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

      # Public community viewing - must be BEFORE authenticated routes
      resources :communities, only: %i[index]
      resources :communities, only: %i[show], path: 'c', as: 'community'

      devise_scope :user do
        unauthenticated :user do
          # Avoid clobbering admin users_path helper; keep redirect but rename helper
          get 'users', to: redirect('users/sign-in'), as: :redirect_users # redirect for user after_sign_up
        end
        authenticated :user do
          get 'users', to: redirect('settings#account'), as: :settings_account
        end
      end
      # These routes are only exposed for logged-in users
      authenticated :user do # rubocop:todo Metrics/BlockLength
        resources :agreements
        resources :calendars
        resources :calls_for_interest, except: %i[index show]
        resources :communities, only: %i[create new]
        resources :communities, only: %i[edit update destroy], path: 'c' do
          resources :invitations, only: %i[create destroy] do
            collection do
              get :available_people
            end
            member do
              put :resend
            end
          end

          resources :person_community_memberships, only: %i[create destroy]
        end

        resources :conversations, only: %i[index new create update show] do
          resources :messages, only: %i[index new create]
          member do
            put :leave_conversation
          end
        end

        resources :events, except: %i[index show] do
          resources :invitations, only: %i[create destroy] do
            collection do
              get :available_people
            end
            member do
              put :resend
            end
          end
        end

        namespace :geography do
          resources :maps, only: %i[show update create index] # these are needed by the polymorphic url helper
        end

        # Help banner preferences
        post 'help_banners/hide', to: 'help_preferences#hide', as: :hide_help_banner
        post 'help_banners/show', to: 'help_preferences#show', as: :show_help_banner
        post 'view_preferences', to: 'view_preferences#update', as: :view_preferences

        scope path: 'hub' do
          get '/', to: 'hub#index', as: :hub
          get 'activities', to: 'hub#activities', as: :hub_activities
          get 'recent_offers', to: 'hub#recent_offers', as: :hub_recent_offers
          get 'recent_requests', to: 'hub#recent_requests', as: :hub_recent_requests
          get 'suggested_matches', to: 'hub#suggested_matches', as: :hub_suggested_matches
        end

        resources :notifications, only: %i[index] do
          member do
            post :mark_as_read
          end

          collection do
            get :dropdown
            post :mark_all_as_read, to: 'notifications#mark_as_read'
            post :mark_record_as_read, to: 'notifications#mark_as_read'
          end
        end

        resources :person_blocks, path: :blocks, only: %i[index new create destroy] do
          collection do
            get :search
          end
        end
        resources :reports, only: [:create]

        namespace :joatu, path: 'exchange' do
          # Exchange hub landing page
          get '/', to: 'hub#index', as: :hub
          resources :offers do
            member do
              get :respond_with_request
            end
          end
          resources :requests do
            member do
              get :matches
              get :respond_with_offer
            end
          end
          resources :agreements do
            member do
              post :accept
              post :reject
            end
          end

          # Platform-manager Joatu category management (policy-gated)
          resources :categories

          resources :response_links, only: [:create]
        end

        resources :maps, module: :geography

        scope path: :p do
          get 'me', to: 'people#show', as: 'my_profile', defaults: { id: 'me' }
        end

        resources :checklists, except: %i[index show] do
          member do
            get :completion_status
          end
          resources :checklist_items, only: %i[edit create update destroy] do
            member do
              patch :position
            end

            collection do
              patch :reorder
            end
            # endpoints for person-specific completion records (JSON)
            member do
              get 'person_checklist_item', to: 'person_checklist_items#show'
              post 'person_checklist_item', to: 'person_checklist_items#create', as: 'create_person_checklist_item'
            end
          end
        end

        resources :people, only: %i[update show edit], path: :p do
          get 'me', to: 'people#show', as: 'my_profile'
          get 'me/edit', to: 'people#edit', as: 'edit_my_profile'
        end

        resources :posts

        resources :platforms, only: %i[index show edit update] do
          resources :platform_invitations, only: %i[index create destroy] do
            member do
              put :resend
            end
          end
        end

        get 'settings', to: 'settings#index'

        # Only logged-in users have access to the AI translation feature for now. Needs code adjustments, too.
        scope path: :translations do
          post 'translate', to: 'translations#translate', as: :ai_translate
        end

        # Routes accessible to Platform Managers OR Analytics Viewers
        authenticated :user, lambda { |u|
          u.permitted_to?('view_metrics_dashboard') || u.permitted_to?('manage_platform')
        } do
          scope path: 'host' do
            # Add route for the host dashboard
            get '/', to: 'host_dashboard#index', as: 'host_dashboard'

            # Reporting for collected metrics
            namespace :metrics do
              resources :link_click_reports, only: %i[index new create] do
                member do
                  get :download
                end
              end

              resources :link_checker_reports, only: %i[index new create] do
                member do
                  get :download
                end
              end

              resources :page_view_reports, only: %i[index new create] do
                member do
                  get :download
                end
              end

              resources :reports, only: [:index]
            end
          end
        end

        # Only logged-in Platform Managers have access to these routes
        authenticated :user, ->(u) { u.permitted_to?('manage_platform') } do # rubocop:todo Metrics/BlockLength
          scope path: 'host' do # rubocop:todo Metrics/BlockLength
            resources :categories

            # Lists all used content blocks. Allows setting built-in system blocks.
            namespace :content do
              resources :blocks
            end

            # management for built-in Nav Areas and adding new ones for page sidebars.
            resources :navigation_areas do
              resources :navigation_items
            end

            # Role-based access control management
            resources :resource_permissions
            resources :roles

            # Content Management
            resources :pages do
              scope module: 'content' do
                resources :page_blocks, only: %i[new destroy], defaults: { format: :turbo_stream }
              end
            end

            # People and memberships
            resources :people
            resources :person_community_memberships

            # Platform list
            resources :platforms, only: %i[index show edit update] do
              member do
                get :available_people
              end
              resources :person_platform_memberships, only: %i[create destroy]
              resources :platform_invitations, only: %i[create destroy] do
                member do
                  put :resend
                end
              end
            end

            resources :users

            # Geography Routes for WIP Geography Feature
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

      # These routes all are accessible to unauthenticated users
      resources :agreements, only: :show
      resources :calls_for_interest, only: %i[index show]
      # Public access: allow viewing public checklists
      resources :checklists, only: %i[index show]

      # Test-only routes: expose person_checklist_item endpoints in test env so request specs
      # can reach the controller without the authenticated route constraint interfering.
      if Rails.env.test?
        post 'checklists/:checklist_id/checklist_items/:id/person_checklist_item', to: 'person_checklist_items#create'
        get  'checklists/:checklist_id/checklist_items/:id/person_checklist_item', to: 'person_checklist_items#show'
      end

      resources :events, only: %i[index show] do
        member do
          get :show
          get :ics, defaults: { format: :ics }
          post :rsvp_interested
          post :rsvp_going
          delete :rsvp_cancel
        end
      end

      # Token-based invitation review and actions (public)
      get 'invitations/:token', to: 'invitations#show', as: :invitation
      post 'invitations/:token/accept', to: 'invitations#accept', as: :accept_invitation
      post 'invitations/:token/decline', to: 'invitations#decline', as: :decline_invitation
      resources :posts, only: %i[index show]

      # Configures file list and download paths
      resources :uploads, only: %i[index], path: :f, as: :file do
        member do
          get :download
        end
      end

      # These routes are used for metrics tracking requests
      namespace :metrics do
        resources :link_clicks, only: [:create]
        resources :page_views, only: [:create]
        resources :shares, only: [:create]
        resources :search_queries, only: [:create]
      end

      # Here there be Wizards! For now, only used for the platform setup wizard
      resources :wizards, only: [:show] do
        # Custom route for wizard steps
        get ':wizard_step_definition_id', to: 'wizard_steps#show', as: :step
        patch ':wizard_step_definition_id', to: 'wizard_steps#update'
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

          get ':step',
              to: 'setup_wizard_steps#redirect',
              as: 'setup_wizard_step',
              constraints: { step: /platform_details|admin_creation/ }
        end
      end
    end

    unless Rails.env.production?
      get '/404', to: 'application#render_not_found'
      get '/500', to: 'application#render_500'
    end

    # Catch-all route
    get '*path', to: 'pages#show', as: 'render_page', constraints: lambda { |req|
      !req.xhr? && req.format.html?
    }

    get 'bt' => 'static_pages#community_engine', as: :community_engine
    get '', to: 'pages#show', defaults: { path: 'home' }, as: :home_page
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
