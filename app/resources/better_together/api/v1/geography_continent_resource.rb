# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Geography::Continent (read-only)
      class GeographyContinentResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Geography::Continent'
        immutable

        # Override: demodulize strips 'Geography::' causing JSONAPI to look for ContinentResource
        def self.resource_klass_for_model(_model) = self

        attributes :name, :identifier, :slug
      end
    end
  end
end
