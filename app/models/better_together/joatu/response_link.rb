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

      # Ensure source is in a state that can be responded to
      validate :source_must_be_respondable

      after_commit :mark_source_matched, on: :create

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
      def notify_match # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize, Metrics/MethodLength, Metrics/PerceivedComplexity
        # Symmetric notifications for direct response links
        if source.is_a?(BetterTogether::Joatu::Offer) && response.is_a?(BetterTogether::Joatu::Request)
          return unless source.creator

          notifier = BetterTogether::Joatu::MatchNotifier.with(offer: source, request: response)
          notifier.deliver_later([source.creator])
        elsif source.is_a?(BetterTogether::Joatu::Request) && response.is_a?(BetterTogether::Joatu::Offer)
          return unless source.creator

          notifier = BetterTogether::Joatu::MatchNotifier.with(offer: response, request: source)
          notifier.deliver_later([source.creator])
        end
      rescue StandardError
        # Do not raise — notifications should not break the main flow
        Rails.logger.error("Failed to deliver match notification for ResponseLink #{id}")
      end

      def source_must_be_respondable
        return unless source.respond_to?(:status)

        allowed = %w[open matched]
        return if allowed.include?(source.status)

        errors.add(:source, 'must be open or matched to create a response')
      end

      def mark_source_matched
        return unless source.respond_to?(:status)

        # Only transition an open source to matched; leave other states alone
        source.status_matched! if source.status == 'open'
      rescue StandardError => e
        Rails.logger.error("Failed to mark source ##{source&.id} as matched: #{e.message}")
      end
    end
  end
end
