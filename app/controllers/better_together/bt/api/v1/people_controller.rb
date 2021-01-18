require_dependency "better_together/api_controller"

module BetterTogether
  module Bt
    module Api
      module V1   
        class PeopleController < ApiController
          before_action :authenticate_user!
        end
      end
    end
  end
end
