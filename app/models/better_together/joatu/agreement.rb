# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Agreement connects an offer and request and tracks value exchange
    class Agreement < ApplicationRecord
      STATUS_VALUES = {
        pending: 'pending',
        accepted: 'accepted',
        rejected: 'rejected'
      }.freeze

      belongs_to :offer, class_name: 'BetterTogether::Joatu::Offer'
      belongs_to :request, class_name: 'BetterTogether::Joatu::Request'

      validates :offer, :request, presence: true
      validates :status, presence: true, inclusion: { in: STATUS_VALUES.values }
      validate :offer_matches_request_target

      enum status: STATUS_VALUES, _prefix: :status

      after_create_commit :notify_creators

      after_update_commit :notify_status_change, if: -> { saved_change_to_status? }

      def accept!
        transaction do
          update!(status: :accepted)
          offer.status_closed!
          request.status_closed!
        end
      end

      def reject!
        update!(status: :rejected)
      end

      private

      # Ensures the offer targets the same record as the request
      def offer_matches_request_target
        return unless targets_present?
        return if offer.target_type == request.target_type && offer.target_id == request.target_id

        errors.add(:offer, 'target does not match request target')
      end

      def targets_present?
        offer && request &&
          [offer, request].all? { |r| r.respond_to?(:target_type) && r.respond_to?(:target_id) }
      end

      def notify_creators
        AgreementNotifier.with(record: self).deliver_later([offer.creator, request.creator])
      end

      def notify_status_change
        notifier = BetterTogether::Joatu::AgreementStatusNotifier.with(record: self)
        notifier.deliver_later(offer.creator) if offer&.creator
        notifier.deliver_later(request.creator) if request&.creator
      end
    end
  end
end
