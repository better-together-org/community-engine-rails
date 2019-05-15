Rails.application.routes.draw do

  mount BetterTogether::Community::Engine => "/better_together/community"
end
