# frozen_string_literal: true

module BetterTogether
  module Api
    module V1
      # JSONAPI resource for Joatu::Request
      class JoatuRequestResource < ::BetterTogether::Api::ApplicationResource
        model_name '::BetterTogether::Joatu::Request'

        # Override: demodulize strips 'Joatu::' causing JSONAPI to look for RequestResource
        def self.resource_klass_for_model(_model) = self

        translatable_attribute :name

        attributes :slug, :status, :urgency, :privacy

        has_one :creator, class_name: 'Person'
        has_many :agreements, class_name: 'JoatuAgreement'

        filter :status
        filter :urgency
        filter :privacy

        def self.creatable_fields(_context)
          %i[name status urgency privacy]
        end

        def self.updatable_fields(_context)
          %i[name status urgency privacy]
        end
      end
    end
  end
end
