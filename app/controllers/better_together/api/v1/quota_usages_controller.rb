# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Read-only JSONAPI endpoint for BetterTogether::QuotaUsage (the append-only
      # ledger). QuotaUsagePolicy::Scope restricts visibility to the caller's own
      # owned usage rows, or everything for a platform manager.
      class QuotaUsagesController < BetterTogether::Api::ApplicationController
        before_action :authenticate_user!

        # GET /api/v1/quota_usages
        def index
          super
        end

        # GET /api/v1/quota_usages/:id
        def show
          super
        end
      end
    end
  end
end
