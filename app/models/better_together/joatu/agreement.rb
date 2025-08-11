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

      enum status: STATUS_VALUES, _prefix: :status

      after_create_commit :notify_creators

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

      def notify_creators
        AgreementNotifier.with(record: self).deliver_later(offer.creator, request.creator)
      end
    end
  end
end
