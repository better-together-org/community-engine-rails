# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Joatu::Agreement
      class JoatuAgreementResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Joatu::Agreement'

        # Override: demodulize strips 'Joatu::' causing JSONAPI to look for AgreementResource
        def self.resource_klass_for_model(_model) = self

        attributes :slug, :status, :terms, :value, :privacy

        has_one :offer, class_name: 'JoatuOffer'
        has_one :request, class_name: 'JoatuRequest'

        filter :status
        filter :privacy

        def self.creatable_fields(_context)
          %i[offer request terms value privacy]
        end

        def self.updatable_fields(_context)
          %i[terms value privacy]
        end
      end
    end
  end
end
