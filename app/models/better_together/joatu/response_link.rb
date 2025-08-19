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

      after_commit :notify_match, on: :create

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

      # When a direct response link is created from an Offer -> Request,
      # notify the offer creator about the match.
      def notify_match
        return unless source.is_a?(BetterTogether::Joatu::Offer) && response.is_a?(BetterTogether::Joatu::Request)
        return unless source.creator

        notifier = BetterTogether::Joatu::MatchNotifier.with(offer: source, request: response)
        # Notify only the offer creator about this direct response
        notifier.deliver_later([source.creator])
      rescue StandardError
        # Do not raise — notifications should not break the main flow
        Rails.logger.error("Failed to deliver match notification for ResponseLink #{id}")
      end
    end
  end
end
