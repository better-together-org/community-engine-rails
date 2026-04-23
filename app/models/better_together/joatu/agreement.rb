# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Agreement connects an offer and request and tracks value exchange
    class Agreement < ApplicationRecord # rubocop:todo Metrics/ClassLength
      include BetterTogether::Authorable
      include BetterTogether::Citable
      include BetterTogether::Claimable
      include FriendlySlug
      include BetterTogether::Privacy
      include Metrics::Viewable

      STATUS_VALUES = {
        pending: 'pending',
        accepted: 'accepted',
        cancelled: 'cancelled',
        rejected: 'rejected',
        fulfilled: 'fulfilled'
      }.freeze

      # Use UUID id to generate a stable, unique slug without touching
      # translated attributes or associated records during creation.
      slugged :to_s

      belongs_to :offer, class_name: 'BetterTogether::Joatu::Offer'
      belongs_to :request, class_name: 'BetterTogether::Joatu::Request'
      has_one :settlement, class_name: 'BetterTogether::Joatu::Settlement',
                           dependent: :destroy

      validates :offer, :request, presence: true
      validates :status, presence: true, inclusion: { in: STATUS_VALUES.values }
      validate :offer_matches_request_target

      enum :status, STATUS_VALUES, prefix: :status

      after_create_commit :notify_creators

      # When an agreement is created, mark the paired offer/request as matched
      after_create :mark_associated_matched
      after_create :add_participant_contributions

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
        super + %i[offer_id request_id terms value status privacy]
      end

      def agreement_family
        'transactional_agreement'
      end

      def agreement_type
        return 'network_connection_agreement' if connection_request?
        return 'person_link_agreement' if request.is_a?(BetterTogether::Joatu::PersonLinkRequest)
        return 'person_access_grant_agreement' if request.is_a?(BetterTogether::Joatu::PersonAccessGrantRequest)

        agreement_family
      end

      def participant_people
        [offer&.creator, request&.creator].compact.uniq
      end

      def participant_ids
        participant_people.map(&:id)
      end

      def participant_for?(person_or_user)
        person = if person_or_user.is_a?(BetterTogether::User)
                   person_or_user.person
                 else
                   person_or_user
                 end

        participant_ids.include?(person&.id)
      end

      def participant_roles
        {
          offer_creator: offer&.creator,
          request_creator: request&.creator
        }.compact
      end

      def participant_names
        participant_people.map { |participant| participant.name.presence || participant.to_s }
      end

      def decision_made_at
        return unless status_accepted? || status_rejected? || status_cancelled?

        updated_at
      end

      def accept! # rubocop:todo Metrics/MethodLength
        ensure_accept_allowed!

        transaction do
          update!(status: :accepted)
          offer.status_closed!
          request.status_closed!
          request.after_agreement_acceptance!(offer:)
          create_settlement_if_c3_priced!
        end
      end

      # Mark the agreement fulfilled and complete the C3 settlement transfer.
      # Requires an accepted agreement with a pending settlement.
      def fulfill! # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        unless status_accepted?
          errors.add(:base, 'Agreement must be accepted before it can be fulfilled')
          raise ActiveRecord::RecordInvalid, self
        end

        transaction do
          if settlement&.status == 'pending' && settlement.c3_millitokens.positive?
            payer_balance = BetterTogether::C3::Balance.find_by!(holder: settlement.payer)
            recipient_balance = BetterTogether::C3::Balance.find_or_create_by!(holder: settlement.recipient)
            settlement.complete!(payer_balance:, recipient_balance:)
          end
          update!(status: :fulfilled)
        end
      end

      def reject!
        ensure_reject_allowed!
        update!(status: :rejected)
      end

      def cancel! # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        ensure_cancel_allowed!

        transaction do
          if settlement&.status == 'pending'
            payer_balance = BetterTogether::C3::Balance.find_by!(holder: settlement.payer)
            settlement.cancel!(payer_balance: payer_balance)
          end

          update!(status: :cancelled)
          reopen_associated_exchanges!
        end
      end

      def to_s
        "#{offer} ↔ #{request}"
      end

      def connection_request?
        request.is_a?(BetterTogether::Joatu::ConnectionRequest)
      end

      def platform_connection
        return unless connection_request?

        BetterTogether::PlatformConnection.find_by(
          source_platform: offer&.target,
          target_platform: request&.target
        )
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

      def ensure_cancel_allowed!
        return if status_accepted?

        errors.add(:base, 'Agreement must be accepted before it can be cancelled')
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
        when STATUS_VALUES[:accepted]
          # Accepted can only move forward to fulfilled or cancelled
          unless [STATUS_VALUES[:fulfilled], STATUS_VALUES[:cancelled]].include?(to)
            errors.add(:status, 'can only move from accepted to fulfilled or cancelled')
          end
        when STATUS_VALUES[:rejected], STATUS_VALUES[:fulfilled], STATUS_VALUES[:cancelled]
          errors.add(:status, 'cannot change once rejected, cancelled, or fulfilled')
        else
          errors.add(:status, 'has an invalid transition')
        end
      end

      # Ensures the offer targets the same record as the request
      def offer_matches_request_target
        return unless targets_present?
        return if connection_request_target_pair?
        return if person_link_request_target_pair?
        return if person_access_grant_request_target_pair?
        return if offer.target_type == request.target_type && offer.target_id == request.target_id

        errors.add(:offer, 'target does not match request target')
      end

      def targets_present?
        offer && request &&
          [offer, request].all? { |r| r.respond_to?(:target_type) && r.respond_to?(:target_id) }
      end

      def connection_request_target_pair?
        request.is_a?(BetterTogether::Joatu::ConnectionRequest) &&
          offer.target.is_a?(BetterTogether::Platform) &&
          request.target.is_a?(BetterTogether::Platform)
      end

      def person_link_request_target_pair?
        request.is_a?(BetterTogether::Joatu::PersonLinkRequest) &&
          offer.target.is_a?(BetterTogether::Person) &&
          request.target.is_a?(BetterTogether::Person)
      end

      def person_access_grant_request_target_pair?
        request.is_a?(BetterTogether::Joatu::PersonAccessGrantRequest) &&
          offer.target.is_a?(BetterTogether::Person) &&
          request.target.is_a?(BetterTogether::Person)
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

      def add_participant_contributions
        [offer&.creator, request&.creator].compact.uniq.each do |participant|
          add_governed_contributor(
            participant,
            role: BetterTogether::Authorship::EXCHANGE_PARTICIPANT_ROLE,
            contribution_type: BetterTogether::Authorship::COMMUNITY_EXCHANGE_CONTRIBUTION
          )
        end
      end

      # Create a pending Settlement and lock C3 from the payer (request creator)
      # when the offer carries a C3 price. No-op if the offer has no C3 price.
      #
      # The lock_ref returned by Balance#lock! is stored on the Settlement so that
      # Settlement#complete! and Settlement#cancel! can finalise the BalanceLock record
      # (marking it settled or released) rather than leaving it pending until expiry.
      def create_settlement_if_c3_priced! # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        price_millitokens = offer.try(:c3_price_millitokens).to_i
        return unless price_millitokens.positive?

        payer = request.creator
        return unless payer

        payer_balance = BetterTogether::C3::Balance.find_or_create_by!(holder: payer)
        captured_lock_ref = payer_balance.lock!(
          price_millitokens.to_f / BetterTogether::C3::Token::MILLITOKEN_SCALE,
          agreement_ref: id
        )

        new_settlement = create_settlement!(
          payer: payer,
          recipient: offer.creator,
          c3_millitokens: price_millitokens,
          lock_ref: captured_lock_ref,
          status: 'pending'
        )

        BetterTogether::C3::SettlementNotifier
          .with(settlement: new_settlement, event_type: :c3_locked)
          .deliver_later([payer, offer.creator].compact.uniq)
      end

      def reopen_associated_exchanges!
        reopen_exchange!(offer)
        reopen_exchange!(request)
      end

      def reopen_exchange!(record)
        return unless record.respond_to?(:status) && record.status_closed?

        next_status =
          if record.agreements.where.not(id: id).where(status: STATUS_VALUES[:pending]).exists?
            :matched
          else
            :open
          end

        record.public_send(:"status_#{next_status}!")
      end
    end
  end
end
