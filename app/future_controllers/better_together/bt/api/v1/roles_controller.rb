# frozen_string_literal: true

require_dependency 'better_together/api_controller'

module BetterTogether
  module Bt
    module Api
      module V1
        # JSONAPI resource for roles
        class RolesController < ApiController
          before_action :authenticate_user!
        end
      end
    end
  end
end
