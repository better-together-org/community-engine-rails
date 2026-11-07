# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Read-only JSONAPI resource for BetterTogether::QuotaBalance - the materialized
      # consumed/reserved numbers a usage/limit dashboard or external poller actually
      # wants (see the quota_grants Phase 5b PR's scope note on folding this in
      # instead of a separate Prometheus /metrics endpoint).
      class QuotaBalanceResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::QuotaBalance'
        immutable

        attributes :period_key, :consumed, :reserved, :recalculated_at

        has_one :quota

        filter :period_key
      end
    end
  end
end
