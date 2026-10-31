# frozen_string_literal: true

module BetterTogether
  module Billing
    # Which agreements apply to a purchase, in the order a buyer should read them.
    #
    # Every platform has default terms (a requirement with no target). A seller or a product can
    # add its own, or replace the defaults. A payment method brings terms of its own (what cash,
    # a cheque or an e-transfer cannot do) that are always added.
    #
    #   base          the platform's defaults for this purpose (no target, no method)
    #   seller/plan   terms narrowed to the seller or product being bought; a requirement whose
    #                 mode is `replaces_default` removes the base terms instead of adding to them
    #   method        terms that come with the payment method chosen; always added
    #
    # Most general first, so a buyer reads the platform's terms before the seller's.
    class AgreementResolver
      Resolution = Data.define(:requirements) do
        def agreements = requirements.map(&:agreement).uniq

        # Whether anything other than a payment method's own terms applies. A purchase with only
        # method terms has no purchase agreement, which is a mistake to fix before selling.
        def base_terms? = requirements.any? { |requirement| !requirement.method_specific? }
      end

      def self.call(...) = new(...).call

      def initialize(platform:, purpose:, seller: nil, purchasables: [], payment_method: nil)
        @platform = platform
        @purpose = purpose.to_s
        @seller = seller
        @purchasables = Array(purchasables)
        @payment_method = payment_method&.to_s
      end

      def call
        applicable = rows.select { |requirement| applies?(requirement) }
        applicable -= replaced_defaults(applicable)
        Resolution.new(requirements: applicable.sort_by { |requirement| order_key(requirement) })
      end

      private

      attr_reader :platform, :purpose, :seller, :purchasables, :payment_method

      # Only this platform's requirements are ever read.
      def rows
        platform.billing_agreement_requirements.includes(:agreement).for_purpose(purpose).for_method(payment_method).to_a
      end

      def applies?(requirement)
        requirement.platform_default? || targets.include?([requirement.target_type, requirement.target_id])
      end

      def targets
        @targets ||= ([seller] + purchasables).compact.map { |record| [record.class.name, record.id] }
      end

      # A narrower requirement that replaces the defaults takes the base terms out. Terms that
      # belong to a payment method are never replaced: they describe the method, not the product.
      def replaced_defaults(applicable)
        return [] unless applicable.any? { |requirement| requirement.replaces_default? && !requirement.platform_default? }

        applicable.select { |requirement| requirement.platform_default? && !requirement.method_specific? }
      end

      def order_key(requirement)
        [requirement.method_specific? ? 1 : 0, requirement.specificity, requirement.position, requirement.created_at.to_f]
      end
    end
  end
end
