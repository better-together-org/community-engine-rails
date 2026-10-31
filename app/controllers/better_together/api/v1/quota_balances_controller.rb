# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Read-only JSONAPI endpoint for BetterTogether::QuotaBalance - the materialized
      # consumed/reserved numbers. QuotaBalancePolicy::Scope restricts visibility to
      # balances whose Quota is owned by the caller, or everything for a platform
      # manager.
      class QuotaBalancesController < BetterTogether::Api::ApplicationController
        before_action :authenticate_user!

        # GET /api/v1/quota_balances
        def index
          super
        end

        # GET /api/v1/quota_balances/:id
        def show
          super
        end
      end
    end
  end
end
