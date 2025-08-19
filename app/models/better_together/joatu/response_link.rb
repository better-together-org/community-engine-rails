# frozen_string_literal: true

module BetterTogether
  module Joatu
    # ResponseLink represents an explicit user-created link between a source
    # Offer/Request and the Offer/Request created in response.
    class ResponseLink < ApplicationRecord
      include Creatable

      belongs_to :source, polymorphic: true
      belongs_to :response, polymorphic: true

      validates :source, :response, presence: true

      validate :disallow_same_type_link

      def self.permitted_attributes(id: true, destroy: false)
        super + %i[
          source_type source_id response_type response_id
        ]
      end

      private

      # We only support Offer -> Request or Request -> Offer links
      def disallow_same_type_link
        return unless source && response
        return if source.class != response.class

        errors.add(:base, 'Response must be of the opposite type to the source')
      end
    end
  end
end
