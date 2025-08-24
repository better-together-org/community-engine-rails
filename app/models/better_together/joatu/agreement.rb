# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Agreement connects an offer and request and tracks value exchange
    class Agreement < ApplicationRecord # rubocop:todo Metrics/ClassLength
      include FriendlySlug
      include Metrics::Viewable

      STATUS_VALUES = {
        pending: 'pending',
        accepted: 'accepted',
        rejected: 'rejected'
      }.freeze

      # Use UUID id to generate a stable, unique slug without touching
      # translated attributes or associated records during creation.
      slugged :to_s

      belongs_to :offer, class_name: 'BetterTogether::Joatu::Offer'
      belongs_to :request, class_name: 'BetterTogether::Joatu::Request'

      validates :offer, :request, presence: true
      validates :status, presence: true, inclusion: { in: STATUS_VALUES.values }
      validate :offer_matches_request_target

      enum status: STATUS_VALUES, _prefix: :status

      after_create_commit :notify_creators

      # When an agreement is created, mark the paired offer/request as matched
      after_create :mark_associated_matched

      after_update_commit :notify_status_change, if: -> { saved_change_to_status? }

      # Prevent illegal status transitions regardless of entry point
      validate :validate_status_transition

      # Only one accepted agreement per offer/request (enforced at DB too)
      validates :offer_id, uniqueness: {
        conditions: -> { where(status: STATUS_VALUES[:accepted]) },
        message: 'already has an accepted agreement'
      }, if: :status_accepted?

      validates :request_id, uniqueness: {
        conditions: -> { where(status: STATUS_VALUES[:accepted]) },
        message: 'already has an accepted agreement'
      }, if: :status_accepted?

      def self.permitted_attributes(id: false, destroy: false)
        super + %i[offer_id request_id terms value status]
      end

      def accept!
        ensure_accept_allowed!

        transaction do
          update!(status: :accepted)
          offer.status_closed!
          request.status_closed!
        end
      end

      def reject!
        ensure_reject_allowed!
        update!(status: :rejected)
      end

      def to_s
        "#{offer} ↔ #{request}"
      end

      private

      def ensure_accept_allowed! # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        if status_accepted?
          errors.add(:base, 'Agreement already accepted')
          raise ActiveRecord::RecordInvalid, self
        end

        if status_rejected?
          errors.add(:base, 'Agreement already rejected')
          raise ActiveRecord::RecordInvalid, self
        end

        if offer.respond_to?(:status_closed?) && offer.status_closed?
          errors.add(:offer, 'is already closed')
          raise ActiveRecord::RecordInvalid, self
        end

        return unless request.respond_to?(:status_closed?) && request.status_closed?

        errors.add(:request, 'is already closed')
        raise ActiveRecord::RecordInvalid, self
      end

      def ensure_reject_allowed! # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        if status_accepted?
          errors.add(:base, 'Agreement already accepted')
          raise ActiveRecord::RecordInvalid, self
        end

        if status_rejected?
          errors.add(:base, 'Agreement already rejected')
          raise ActiveRecord::RecordInvalid, self
        end

        if offer.respond_to?(:status_closed?) && offer.status_closed?
          errors.add(:offer, 'is already closed')
          raise ActiveRecord::RecordInvalid, self
        end

        return unless request.respond_to?(:status_closed?) && request.status_closed?

        errors.add(:request, 'is already closed')
        raise ActiveRecord::RecordInvalid, self
      end

      def validate_status_transition # rubocop:todo Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
        return unless will_save_change_to_status?

        from, to = status_change_to_be_saved

        # On create (from nil), only allow pending
        if from.nil?
          errors.add(:status, 'must start as pending') unless to == STATUS_VALUES[:pending]
          return
        end

        # No-op changes are fine
        return if from == to

        case from
        when STATUS_VALUES[:pending]
          # Allow only transitions to accepted or rejected from pending
          unless [STATUS_VALUES[:accepted], STATUS_VALUES[:rejected]].include?(to)
            errors.add(:status, 'can only move from pending to accepted or rejected')
          end
          # If moving to accepted via direct update, block when sides are already closed
          if to == STATUS_VALUES[:accepted]
            errors.add(:offer, 'is already closed') if offer.respond_to?(:status_closed?) && offer.status_closed?
            errors.add(:request, 'is already closed') if request.respond_to?(:status_closed?) && request.status_closed?
          end
        when STATUS_VALUES[:accepted], STATUS_VALUES[:rejected]
          errors.add(:status, 'cannot change once accepted or rejected')
        else
          errors.add(:status, 'has an invalid transition')
        end
      end

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

      def mark_associated_matched # rubocop:todo Metrics/CyclomaticComplexity, Metrics/AbcSize
        return unless offer && request

        begin
          offer.status_matched! if offer.respond_to?(:status) && offer.status == 'open'
          request.status_matched! if request.respond_to?(:status) && request.status == 'open'
        rescue StandardError => e
          Rails.logger.error("Failed to mark associated records matched for Agreement #{id}: #{e.message}")
        end
      end

      def notify_status_change
        notifier = BetterTogether::Joatu::AgreementStatusNotifier.with(record: self)
        notifier.deliver_later(offer.creator) if offer&.creator
        notifier.deliver_later(request.creator) if request&.creator
      end
    end
  end
end
