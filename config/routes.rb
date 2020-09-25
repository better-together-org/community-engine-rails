BetterTogether::Engine.routes.draw do
  scope path: 'bt' do
    get '/' => 'static_pages#home'
  end

  namespace :bt do
    namespace :api do
      namespace :v1 do
        jsonapi_resources :communities do
          jsonapi_relationships
        end

        jsonapi_resources :community_memberships do
          jsonapi_relationships
        end

        jsonapi_resources :people do
          jsonapi_relationships
        end

        jsonapi_resources :roles do
          jsonapi_relationships
        end
      end
    end
  end
end
