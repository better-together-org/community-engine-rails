require_dependency "better_together/api_controller"

module BetterTogether
  module Api
    module V1   
      class CommunitiesController < ApiController
        def index
          render json: Community.all
        end
      end
    end
  end
end
