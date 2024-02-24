require_dependency 'better_together/api_controller'

module BetterTogether
  module Bt
    module Api
      module V1
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
