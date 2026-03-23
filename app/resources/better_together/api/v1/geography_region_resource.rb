# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Geography::Region (read-only)
      class GeographyRegionResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Geography::Region'
        immutable

        # Override: demodulize strips 'Geography::' causing JSONAPI to look for RegionResource
        def self.resource_klass_for_model(_model) = self

        attributes :name, :identifier, :slug
      end
    end
  end
end
