# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Geography::Country (read-only)
      class GeographyCountryResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Geography::Country'
        immutable

        # Override: demodulize strips 'Geography::' causing JSONAPI to look for CountryResource
        def self.resource_klass_for_model(_model) = self

        attributes :name, :identifier, :slug, :iso_code

        filter :iso_code
      end
    end
  end
end
