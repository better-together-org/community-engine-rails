# frozen_string_literal: true

module BetterTogether
  # Enforces the publishing agreement requirement before governed agents make
  # records broadly public.
  class PublicVisibilityGate
    AGREEMENT_IDENTIFIER = 'content_publishing_agreement'

    Result = Struct.new(:allowed, :reasons, keyword_init: true) do
      def allowed?
        allowed
      end
    end

    class << self
      def allow!(record:, actor:, target_privacy: nil, target_published_at: nil, target_network_visibility: nil)
        result = evaluate(record:, actor:, target_privacy:, target_published_at:, target_network_visibility:)
        return result if result.allowed?

        result.reasons.each do |reason|
          record.errors.add(:base, error_message_for(reason))
        end
        result
      end

      def evaluate(record:, actor:, target_privacy: nil, target_published_at: nil, target_network_visibility: nil)
        return Result.new(allowed: true, reasons: []) unless public_exposure_requested?(
          record:,
          target_privacy:,
          target_published_at:,
          target_network_visibility:
        )
        return Result.new(allowed: true, reasons: []) if actor.blank?

        reasons = []
        reasons << :missing_publishing_agreement unless ChecksRequiredAgreements.accepted_public_publishing_agreement?(actor)
        Result.new(allowed: reasons.empty?, reasons:)
      end

      def error_message_for(reason)
        case reason
        when :missing_publishing_agreement
          'The content publishing agreement must be accepted before this can be made public.'
        else
          'This record cannot be made public.'
        end
      end

      def public_exposure_requested?(record:, target_privacy: nil, target_published_at: nil, target_network_visibility: nil)
        requested_privacy = target_privacy.presence || record.try(:privacy)
        requested_network_visibility = target_network_visibility.presence || record.try(:network_visibility)
        requested_published_at = target_published_at.nil? ? record.try(:published_at) : target_published_at

        requested_privacy == 'public' ||
          requested_network_visibility == 'public' ||
          public_publication_requested?(record, requested_published_at)
      end

      private

      def public_publication_requested?(record, requested_published_at)
        return false if requested_published_at.blank?
        return true unless record.respond_to?(:privacy_public?)

        record.privacy_public?
      end
    end
  end
end
