BetterTogether::Engine.routes.draw do
  devise_for :api_users,
    class_name: BetterTogether.user_class.to_s,
    skip: [:unlocks, :omniauth_callbacks],
    path: 'bt/api/auth',
    path_names: {
      sign_in: 'sign-in',
      sign_out: 'sign-out',
      registration: 'sign-up'
    },
    defaults: { format: :json }

  devise_for :users,
    class_name: BetterTogether.user_class.to_s,
    skip: [:unlocks, :omniauth_callbacks],
    path: 'bt/users',
    path_names: {
      sign_in: 'sign-in',
      sign_out: 'sign-out',
      registration: 'sign-up'
    },
    defaults: { format: :html }

  # bt base path
  scope path: 'bt' do
    get '/' => 'static_pages#home'

    
  end

  namespace :bt do
    namespace :api, defaults: { format: :json } do
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
