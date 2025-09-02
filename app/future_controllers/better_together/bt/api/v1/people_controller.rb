# frozen_string_literal: true

require 'better_together/api_controller'

module BetterTogether
  module Bt
    module Api
      module V1
        # JSONAPI resource for people
        class PeopleController < ApiController
          before_action :authenticate_user!

          def me
            @policy_used = person = authorize current_user.person

            render json: person.to_json
          end
        end
      end
    end
  end
end
