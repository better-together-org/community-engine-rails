# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Joatu::Offer
      class JoatuOfferResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Joatu::Offer'

        # Override: demodulize strips 'Joatu::' causing JSONAPI to look for OfferResource
        def self.resource_klass_for_model(_model) = self

        translatable_attribute :name

        attributes :slug, :status, :urgency

        has_one :creator, class_name: 'Person'
        has_many :agreements, class_name: 'JoatuAgreement'

        filter :status
        filter :urgency

        def self.creatable_fields(_context)
          %i[name status urgency]
        end

        def self.updatable_fields(_context)
          %i[name status urgency]
        end
      end
    end
  end
end
