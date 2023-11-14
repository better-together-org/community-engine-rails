module BetterTogether
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    # helper 'better_together/application'
  end
end
