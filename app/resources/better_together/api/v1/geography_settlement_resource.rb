# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Geography::Settlement (read-only)
      class GeographySettlementResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Geography::Settlement'
        immutable

        # Override: demodulize strips 'Geography::' causing JSONAPI to look for SettlementResource
        def self.resource_klass_for_model(_model) = self

        attributes :name, :identifier, :slug
      end
    end
  end
end
