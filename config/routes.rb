BetterTogether::Engine.routes.draw do
  # bt base path
  scope path: 'bt' do
    get '/' => 'static_pages#home'

    devise_for :users,
      class_name: BetterTogether.user_class.to_s,
      module: 'devise',
      skip: [:unlocks, :omniauth_callbacks],
      path: 'users',
      path_names: {
        sign_in: 'sign-in',
        sign_out: 'sign-out',
        registration: 'sign-up'
      },
      defaults: { format: :html }
  end

  namespace :bt do
    namespace :api, defaults: { format: :json } do
      devise_for :users,
        class_name: BetterTogether.user_class.to_s,
        skip: [:unlocks, :omniauth_callbacks],
        path: 'auth',
        path_names: {
          sign_in: 'sign-in',
          sign_out: 'sign-out',
          registration: 'sign-up'
        }

      namespace :v1 do
        jsonapi_resources :communities do
          # jsonapi_relationships
        end

        jsonapi_resources :community_memberships do
          # jsonapi_relationships
        end

        get 'people/me', to: 'people#me'

        jsonapi_resources :people do
          # jsonapi_relationships
        end

        jsonapi_resources :roles do
          # jsonapi_relationships
        end
      end
    end
  end
end
