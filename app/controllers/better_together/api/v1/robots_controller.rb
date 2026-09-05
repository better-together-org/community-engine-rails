# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource controller for robots
      class RobotsController < BetterTogether::Api::ApplicationController
        before_action :ensure_robot_api_access_enabled!

        def index
          super
        end

        def show
          super
        end

        def create
          super
        end

        def update
          super
        end

        private

        # Robot API access is a gated surface (config/feature_gates.yml: robot_api_access,
        # default_rollout: beta). Raising here reuses ApplicationController#handle_exceptions,
        # which converts Pundit::NotAuthorizedError into a 404 rather than a revealing 403.
        def ensure_robot_api_access_enabled!
          return if BetterTogether::FeatureGate.enabled?('robot_api_access', actor: current_user)

          raise Pundit::NotAuthorizedError
        end
      end
    end
  end
end
