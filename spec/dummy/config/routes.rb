Rails.application.routes.draw do

  mount BetterTogether::Core::Engine => "/better_together/core"
end
