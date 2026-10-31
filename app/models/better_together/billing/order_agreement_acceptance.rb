# frozen_string_literal: true

module BetterTogether
  module Billing
    # The evidence that a buyer accepted an agreement for one order: which agreement, as it
    # read then (identifier, title, content digest), who accepted, for whom, how and when.
    #
    # The agreement can change, and the same person can accept it again, later; this row is what
    # applied to THIS purchase and is never rewritten. It is tied to its order by a composite
    # foreign key, so the evidence is always on the order's own platform.
    class OrderAgreementAcceptance < ApplicationRecord
      include PlatformBound
      include ParentBound

      self.table_name = 'better_together_billing_order_agreement_acceptances'

      belongs_to :order, class_name: 'BetterTogether::Billing::Order', inverse_of: :agreement_acceptances, optional: false
      belongs_to :agreement, class_name: 'BetterTogether::Agreement', optional: false
      belongs_to :signer, class_name: 'BetterTogether::Person', optional: false
      belongs_to :on_behalf_of, polymorphic: true, optional: true

      validates :agreement_identifier, :agreement_title, :agreement_content_digest, :accepted_at, presence: true
      validates :acceptance_method, inclusion: { in: AgreementParticipant.acceptance_methods.keys }
      validates :agreement_id, uniqueness: { scope: :order_id }
      validate :on_behalf_of_allowed

      # Takes the snapshot from the signer's current acceptance of the agreement.
      def self.record!(order:, agreement:, signer:, on_behalf_of: nil)
        acceptance = agreement.current_acceptance_for(signer)
        raise ArgumentError, 'the signer has not accepted that agreement' unless acceptance

        order.agreement_acceptances.create!(
          platform_id: order.platform_id, agreement:, signer:, on_behalf_of:, agreement_identifier: agreement.identifier,
          agreement_title: agreement.title.to_s, agreement_content_digest: acceptance.agreement_content_digest,
          acceptance_method: acceptance.acceptance_method, accepted_at: acceptance.accepted_at
        )
      end

      # Evidence is never rewritten.
      def readonly? = persisted? || super

      private

      def billing_parent = order

      # Never load an owner whose type is not on the allow-list.
      def on_behalf_of_allowed
        return if on_behalf_of_type.blank? && on_behalf_of_id.blank?

        errors.add(:on_behalf_of_type, :inclusion) unless SellerScoped.assignable_types.include?(on_behalf_of_type)
      end
    end
  end
end
