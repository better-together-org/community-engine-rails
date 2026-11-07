# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Read-only JSONAPI endpoint for BetterTogether::Quota. QuotaPolicy::Scope
      # restricts visibility to the caller's own owned quotas, or everything for a
      # platform manager.
      class QuotasController < BetterTogether::Api::ApplicationController
        before_action :authenticate_user!

        # GET /api/v1/quotas
        def index
          super
        end

        # GET /api/v1/quotas/:id
        def show
          super
        end
      end
    end
  end
end
