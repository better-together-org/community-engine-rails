BetterTogether::Engine.routes.draw do
  scope path: 'bt' do
    get '/' => 'static_pages#home'
  end
end
