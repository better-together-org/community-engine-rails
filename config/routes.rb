# frozen_string_literal: true

BetterTogether::Engine.routes.draw do # rubocop:todo Metrics/BlockLength
  scope '(:locale)', locale: /en|fr|es/ do # rubocop:todo Metrics/BlockLength
    # bt base path
    scope path: 'bt' do # rubocop:todo Metrics/BlockLength
      devise_for :users,
                 class_name: BetterTogether.user_class.to_s,
                 module: 'devise',
                 skip: %i[unlocks omniauth_callbacks],
                 path: 'users',
                 path_names: {
                   sign_in: 'sign-in',
                   sign_out: 'sign-out',
                   sign_up: 'sign-up'
                 },
                 defaults: { format: :html }

      scope path: 'host' do
        # Add route for the host dashboard
        get '/', to: 'host_dashboard#index', as: 'host_dashboard'

        resources :communities do
          resources :person_community_memberships
        end

        resources :navigation_areas do
          resources :navigation_items
        end

        resources :resource_permissions
        resources :roles

        resources :pages
        resources :people
        resources :person_community_memberships
        resources :platforms

        namespace :geography do
          resources :continents, except: %i[new create destroy]
          resources :countries
          resources :regions
          resources :region_settlements
          resources :settlements
          resources :states
        end
      end

      resources :people, only: %i[update show edit], path: :p do
        get 'me', to: 'people#show', as: 'my_profile'
        get 'me/edit', to: 'people#edit', as: 'edit_my_profile'
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
          get '/platform_details', to: 'setup_wizard_steps#platform_details',
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

    get '/bt' => 'static_pages#community_engine'
  end
  # TODO: Re-enable the API routes when the API is in full use and actively being maintained to prevent security issues.
  # namespace :bt do
  #   namespace :api, defaults: { format: :json } do
  #     devise_for :users,
  #       class_name: BetterTogether.user_class.to_s,
  #       skip: [:unlocks, :omniauth_callbacks],
  #       path: 'auth',
  #       path_names: {
  #         sign_in: 'sign-in',
  #         sign_out: 'sign-out',
  #         registration: 'sign-up'
  #       }

  #     namespace :v1 do
  #       jsonapi_resources :communities do
  #         # jsonapi_relationships
  #       end

  #       jsonapi_resources :community_memberships do
  #         # jsonapi_relationships
  #       end

  #       get 'people/me', to: 'people#me'

  #       jsonapi_resources :people do
  #         # jsonapi_relationships
  #       end

  #       jsonapi_resources :roles do
  #         # jsonapi_relationships
  #       end
  #     end
  #   end
  # end
end
