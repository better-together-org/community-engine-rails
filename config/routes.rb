BetterTogether::Engine.routes.draw do
  scope path: 'bt' do
    get '/' => 'static_pages#home'

    namespace :api do
      namespace :v1 do
        resources :communities
      end
    end
  end
end
