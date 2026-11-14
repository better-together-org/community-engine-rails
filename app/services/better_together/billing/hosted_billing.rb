# frozen_string_literal: true

module BetterTogether
  module Billing
    # What a hosted platform may do about billing, decided by what it has accepted from the host. The host itself is never gated.
    #
    #   :billing   any billing at all: needs the hosted platform billing agreement
    #   :local     cash, cheque and e-transfer: also needs the hosted local billing agreement
    #   :merchant  the host collecting as merchant of record: also needs the merchant onboarding agreement (the mode is built later)
    #
    # An agreement counts only while the host has it in force and the platform accepted it as it reads now, so withdrawing or
    # replacing one pauses that mode without deleting anything. A platform the host suspended has no mode at all. Fails closed.
    module HostedBilling
      MODES = %i[billing local merchant].freeze

      AGREEMENT_FOR = {
        billing: 'hosted_platform_billing_agreement',
        local: 'hosted_local_billing_agreement',
        merchant: 'merchant_onboarding_agreement'
      }.freeze

      # Modes that need the base billing agreement as well.
      REQUIRES = { billing: [:billing], local: %i[billing local], merchant: %i[billing merchant] }.freeze

      class << self
        def permits?(platform, mode)
          return false if platform.nil?
          return true if platform.host?
          return false if suspended?(platform)

          REQUIRES.fetch(mode.to_sym).all? { |needed| accepted?(platform, needed) }
        end

        # Whether the hosted-billing page (host: false) or the host's status page (host: true) exists for this platform.
        def page_available?(platform, host:)
          platform.present? && platform.host? == host && Configuration.requested? && Configuration.ready?
        end

        def suspended?(platform) = platform.billing_hosted_account&.suspended? || false

        # The host's agreement for a gate, or nil when it was never seeded.
        def agreement(mode)
          host = BetterTogether::Platform.find_by(host: true)
          host && Agreement.billing_record(AGREEMENT_FOR.fetch(mode.to_sym), platform: host)
        end

        def in_force?(agreement) = agreement.present? && agreement.lifecycle_state_active? && agreement.active_for_consent?

        # In force and accepted by this platform as it reads now.
        def accepted?(platform, mode)
          record = agreement(mode)
          in_force?(record) && record.accepted_by?(platform)
        end

        # The platform accepts one agreement. A person acts for it and is recorded in the evidence.
        def accept!(platform:, mode:, person:, request: nil)
          record = agreement(mode)
          raise ArgumentError, "agreement for #{mode} is not in force" unless in_force?(record)

          AgreementAcceptanceRecorder.record!(agreement: record, participant: platform, acceptance_method: 'agreement_review',
                                              context: { request:, accepted_by_person_id: person&.id })
        end

        def suspend!(platform:, by:, reason:)
          account = platform.billing_hosted_account || platform.build_billing_hosted_account
          account.update!(status: 'suspended', suspended_at: Time.current, suspended_by: by, suspension_reason: reason)
          audit(platform, 'hosted_billing.suspended', by, reason:)
          forget(platform)
        end

        def resume!(platform:, by:)
          account = platform.billing_hosted_account
          return if account.nil? || !account.suspended?

          account.update!(status: 'active', suspended_at: nil, suspended_by: nil, suspension_reason: nil)
          audit(platform, 'hosted_billing.resumed', by)
          forget(platform)
        end

        # Platforms the host serves, for the steward page: every non-host platform.
        def hosted_platforms = BetterTogether::Platform.where(host: false).order(:created_at)

        private

        def forget(platform) = Current.billing_enabled&.delete(platform.id)

        # A billing event on the hosted platform (outcome kind settings_changed) naming who and what, never the reason text.
        def audit(platform, kind, by, **detail)
          event_id = SecureRandom.uuid
          platform.billing_events.create!(
            processor: 'hosted_billing', event_id:, event_type: kind, processing_status: 'processed', processed_at: Time.current,
            outcome_kind: 'settings_changed', subject: platform,
            payload: { 'id' => event_id, 'type' => kind, 'outcome_kind' => 'settings_changed', 'actor_id' => by&.id,
                       'reason_given' => detail.key?(:reason) }
          )
        end
      end
    end
  end
end
