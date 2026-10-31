# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Read-only JSONAPI resource for BetterTogether::Quota. owner_type/owner_id are
      # plain attributes, not a JSONAPI relationship: the owner is polymorphic across
      # three unrelated resource classes (Person/Community/Platform), and nothing
      # here needs relationship traversal, just identification.
      class QuotaResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Quota'
        immutable

        attributes :quota_type, :limit, :period, :status, :enforcement_mode,
                   :owner_type, :owner_id

        attribute :effective_limit

        filter :owner_type
        filter :quota_type
      end
    end
  end
end
