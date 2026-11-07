# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Read-only JSONAPI resource for BetterTogether::QuotaUsage (the append-only
      # ledger). owner_type/owner_id/subject_type/subject_id/actor_type/actor_id are
      # plain attributes rather than relationships for the same reason as
      # QuotaResource - multiple unrelated polymorphic target classes.
      class QuotaUsageResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::QuotaUsage'
        immutable

        attributes :quota_type, :amount, :period_key, :event, :owner_type, :owner_id,
                   :subject_type, :subject_id, :actor_type, :actor_id

        has_one :quota

        filter :owner_type
        filter :quota_type
        filter :event
        filter :period_key
      end
    end
  end
end
