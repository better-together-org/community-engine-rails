require_dependency 'better_together/api_controller'

module BetterTogether
  module Bt
    module Api
      module V1
        class CommunitiesController < ApiController
          before_action :authenticate_user!, except: %i[index]
        end
      end
    end
  end
end
