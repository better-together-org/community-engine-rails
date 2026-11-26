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
      include Translatable
      include LocalizedSnapshot

      self.table_name = 'better_together_billing_order_agreement_acceptances'

      # The agreement's title in every language, as it read when it was accepted.
      translates :agreement_title, type: :string

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

        order.agreement_acceptances.build(
          platform_id: order.platform_id, agreement:, signer:, on_behalf_of:, agreement_identifier: agreement.identifier,
          agreement_content_digest: acceptance.agreement_content_digest,
          acceptance_method: acceptance.acceptance_method, accepted_at: acceptance.accepted_at
        ).tap do |record|
          record.snapshot_translations(:agreement_title) { |locale| agreement.title(locale:, fallback: false) }
          record.save!
        end
      end

      # Evidence is never rewritten. The save that creates it also stores the title translations, so it
      # stays writable until that save is over (a record loaded afterwards is read only).
      def readonly? = (persisted? && !previously_new_record?) || super

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
