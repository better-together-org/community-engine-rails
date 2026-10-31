# frozen_string_literal: true

module BetterTogether
  module Billing
    # Seeds a platform's purchase agreements and ties them to the purchases they cover:
    #
    #   subscription_agreement         subscriptions and memberships
    #   one_time_purchase_agreement    one-time purchases, event tickets and exchanges
    #   offline_payment_terms          added when a buyer pays by cash, cheque or e-transfer
    #
    # They are seeded as DRAFTS with placeholder text, and until a steward reviews and activates
    # them nothing can be sold (see Checkout::AgreementGate), so placeholder legal text never goes
    # live by accident. Seeding again never touches an agreement a steward has edited or
    # activated: it only creates what is missing.
    class PurchaseAgreementSeeds
      PLACEHOLDER = 'This is placeholder text. Replace it with your own terms, then set the agreement to active.'

      AGREEMENTS = {
        'subscription_agreement' => {
          title: 'Subscription Agreement',
          description: 'Terms for subscriptions and memberships: what you receive, how renewal works, and how to cancel.'
        },
        'one_time_purchase_agreement' => {
          title: 'One-Time Purchase Agreement',
          description: 'Terms for one-time purchases, event tickets and exchanges: what you receive and how refunds work.'
        },
        'offline_payment_terms' => {
          title: 'Payment Outside the Platform',
          description: 'Terms for paying by cash, cheque or e-transfer: the payment goes straight to the seller, ' \
                       'and the platform cannot track or protect it.'
        }
      }.freeze

      REQUIREMENTS = [
        ['subscription_agreement', 'subscription', nil],
        ['one_time_purchase_agreement', 'one_time', nil],
        ['one_time_purchase_agreement', 'ticket', nil],
        ['one_time_purchase_agreement', 'exchange', nil],
        ['offline_payment_terms', nil, 'cash'],
        ['offline_payment_terms', nil, 'cheque'],
        ['offline_payment_terms', nil, 'etransfer']
      ].freeze

      def self.call(platform) = new(platform).call

      def initialize(platform)
        @platform = platform
      end

      def call
        # The method terms below name the built-in methods, so they must be installed.
        Billing.ensure_builtin_processors!
        agreements = AGREEMENTS.to_h { |identifier, attributes| [identifier, agreement(identifier, attributes)] }
        REQUIREMENTS.each { |identifier, purpose, method| requirement(agreements.fetch(identifier), purpose, method) }
        agreements
      end

      private

      attr_reader :platform

      def agreement(identifier, attributes)
        record = Agreement.find_or_create_by!(identifier:, platform:) do |new_agreement|
          new_agreement.assign_attributes(attributes.merge(protected: true, privacy: 'public', agreement_kind: 'transactional_agreement',
                                                           required_for: 'none', active_for_consent: true, lifecycle_state: 'draft',
                                                           requires_reacceptance: true, change_summary: PLACEHOLDER))
        end
        # A term's identifier is unique across platforms (its table indexes it alone), so it carries the platform.
        record.agreement_terms.find_or_create_by!(identifier: "#{identifier}_summary_#{platform.id.delete('-').first(12)}") do |term|
          term.assign_attributes(protected: true, position: 1, content: PLACEHOLDER)
        end
        record
      end

      def requirement(agreement, purpose, payment_method)
        platform.billing_agreement_requirements.find_or_create_by!(agreement:, purpose:, payment_method:, target_type: nil, target_id: nil)
      end
    end
  end
end
