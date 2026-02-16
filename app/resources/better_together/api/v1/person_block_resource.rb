# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for PersonBlock
      # Allows authenticated users to manage their blocks
      class PersonBlockResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::PersonBlock'

        # Relationships
        has_one :blocker, class_name: 'Person'
        has_one :blocked, class_name: 'Person'

        # Filters
        filter :blocker_id
        filter :blocked_id

        # Attributes for creation
        attribute :blocked_id

        # Only allow creating/deleting - no updates
        def self.updatable_fields(_context)
          []
        end

        def self.creatable_fields(_context)
          %i[blocked_id]
        end
      end
    end
  end
end
