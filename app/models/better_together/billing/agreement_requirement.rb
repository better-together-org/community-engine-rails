# frozen_string_literal: true

module BetterTogether
  module Billing
    # An agreement a buyer must accept before they can pay.
    #
    # With no target it is the platform's default for every purchase. With a target (a seller, a
    # plan) it is that seller's or that product's own terms. It can be limited to one purpose and
    # to one payment method (the terms that come with cash, a cheque or an e-transfer). `mode`
    # says whether it adds to the default terms or replaces them; see AgreementResolver.
    class AgreementRequirement < ApplicationRecord
      include PlatformBound

      self.table_name = 'better_together_billing_agreement_requirements'

      MODES = %w[additional replaces_default].freeze
      # How narrow a target is: nothing (the platform default), a seller, a product.
      SPECIFICITY = { 'BetterTogether::Billing::Plan' => 2 }.freeze

      belongs_to :agreement, class_name: 'BetterTogether::Agreement', optional: false
      belongs_to :target, polymorphic: true, optional: true

      validates :mode, inclusion: { in: MODES }
      validates :purpose, inclusion: { in: ProcessorSetting::PURPOSES }, allow_nil: true
      validates :position, numericality: { only_integer: true }
      validate :payment_method_installed, if: -> { payment_method.present? }
      validate :target_allowed
      validate :agreement_is_a_purchase_agreement_of_this_platform
      validate :not_a_repeat
      before_validation :normalize

      scope :platform_defaults, -> { where(target_id: nil) }
      scope :for_purpose, ->(purpose) { where(purpose: [nil, purpose.to_s]) }
      scope :for_method, ->(method) { where(payment_method: [nil, method.presence&.to_s]) }

      def platform_default? = target_id.nil?

      def method_specific? = payment_method.present?

      def replaces_default? = mode == 'replaces_default'

      def specificity
        return 0 if platform_default?

        SPECIFICITY.fetch(target_type, 1)
      end

      private

      def normalize
        self.purpose = purpose.presence
        self.payment_method = payment_method.presence
        self.target_type = nil if target_id.blank?
      end

      def payment_method_installed
        errors.add(:payment_method, :not_an_offline_method, method: payment_method) unless Billing.offline_method?(payment_method)
      end

      # Never load a target whose type is not on the allow-list.
      def target_allowed
        return if target_id.blank? && target_type.blank?
        return errors.add(:target_type, :inclusion) unless AgreementTarget.model_names.include?(target_type)

        errors.add(:platform, :platform_owner_mismatch) if bound_to_another_platform?(target)
      end

      def agreement_is_a_purchase_agreement_of_this_platform
        return unless agreement

        errors.add(:agreement, :not_a_purchase_agreement) unless agreement.agreement_kind == Agreement::AGREEMENT_KINDS[:transactional_agreement]
        errors.add(:platform, :platform_owner_mismatch) if bound_to_another_platform?(agreement)
      end

      def not_a_repeat
        same = self.class.where(platform_id:, agreement_id:, target_type:, target_id:, purpose:, payment_method:).where.not(id:)
        errors.add(:agreement, :taken) if same.exists?
      end
    end
  end
end
