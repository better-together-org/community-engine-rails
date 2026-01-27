# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # Serializes the Role class
      class RoleResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Role'

        # Translated attributes
        attributes :name, :description

        # Standard attributes
        attributes :identifier, :protected, :position, :resource_type

        # Relationships
        # TODO: Enable when corresponding resources are created
        # has_many :resource_permissions

        # Filters
        filter :resource_type
        filter :protected

        # Creatable and updatable fields (roles are mostly system-managed)
        def self.creatable_fields(_context)
          [] # Roles cannot be created via API
        end

        def self.updatable_fields(context)
          super - %i[identifier protected position resource_type] # These are system-managed
        end
      end
    end
  end
end
