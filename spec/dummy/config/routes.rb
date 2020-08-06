Rails.application.routes.draw do
  mount BetterTogether::Engine => "/"
  root :to => redirect('/bt')
end
