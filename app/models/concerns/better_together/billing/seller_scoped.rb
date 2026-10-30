# frozen_string_literal: true

module BetterTogether
  module Billing
    # Who sells: the platform itself (no seller) or one of its communities or people.
    #
    # Shared by every billing record that a seller owns (plans, processor settings). The
    # seller type is checked against an allow-list before the seller is ever loaded, so a
    # type name is never resolved from a string; the seller must be on the record's own
    # platform; and neither can change once the record exists.
    module SellerScoped
      extend ActiveSupport::Concern

      # Who may sell besides the platform itself. Classes that opt in with
      # Billing::Billable are added (see .assignable_seller_types).
      DEFAULT_SELLER_TYPES = %w[BetterTogether::Community BetterTogether::Person].freeze

      included do
        belongs_to :seller, polymorphic: true, optional: true
        attr_readonly :seller_type, :seller_id

        validate :seller_is_allowed

        # What the platform itself sells, and what one seller sells.
        scope :sold_by_platform, -> { where(seller_id: nil) }
        scope :sold_by, ->(seller) { where(seller_type: seller.class.name, seller_id: seller.id) }
      end

      class_methods do
        def assignable_seller_types
          (DEFAULT_SELLER_TYPES + Billable.model_names.to_a).uniq
        end
      end

      def sold_by_platform? = seller_id.nil?

      private

      def seller_is_allowed
        return if seller_id.blank? && seller_type.blank?

        # Never load a seller whose type is not on the allow-list.
        return errors.add(:seller_type, :inclusion) unless self.class.assignable_seller_types.include?(seller_type)

        errors.add(:platform, :platform_owner_mismatch) if seller_on_another_platform?
      end

      def seller_on_another_platform?
        bound = seller.try(:billing_bound_platform_id) || seller.try(:platform_id)
        bound.present? && platform_id.present? && bound != platform_id
      end
    end
  end
end
