# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Geography::State (read-only)
      class GeographyStateResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Geography::State'
        immutable

        # Override: demodulize strips 'Geography::' causing JSONAPI to look for StateResource
        def self.resource_klass_for_model(_model) = self

        attributes :name, :identifier, :slug, :iso_code

        filter :iso_code
      end
    end
  end
end
