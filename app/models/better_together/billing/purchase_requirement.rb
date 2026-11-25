# frozen_string_literal: true

module BetterTogether
  module Billing
    # A rule that a purchasable (the dependent) may only be bought by someone who meets a prerequisite: one specific
    # purchasable, or a kind of them (`plan` is any primary plan). See docs/billing/purchasable_split_plan.md.
    #
    # * `met_by`: `holding` (the buyer already has it), `in_order` (the same order contains it), or `either` (the default).
    # * `required`: with several rules a dependent needs any one met, and every required rule on top of that.
    # * `on_prerequisite_end`: `keep` (the default) or `revoke` the dependent when the prerequisite is refunded or ends.
    #
    # Both ends are resolved through the Purchasable registry, never from a string.
    class PurchaseRequirement < ApplicationRecord
      include PlatformBound

      self.table_name = 'better_together_billing_purchase_requirements'

      MET_BY = %w[holding in_order either].freeze
      ON_PREREQUISITE_END = %w[keep revoke].freeze
      # Kinds of prerequisite a rule can name instead of one purchasable. Each is a class name the registry holds.
      KINDS = { 'plan' => 'BetterTogether::Billing::Plan' }.freeze

      belongs_to :dependent, polymorphic: true
      belongs_to :prerequisite, polymorphic: true, optional: true

      validates :met_by, inclusion: { in: MET_BY }
      validates :on_prerequisite_end, inclusion: { in: ON_PREREQUISITE_END }
      validates :required, inclusion: { in: [true, false] }
      validates :prerequisite_kind, inclusion: { in: KINDS.keys }, allow_nil: true
      validates :prerequisite_id, uniqueness: { scope: %i[dependent_type dependent_id prerequisite_type] }, allow_nil: true
      validates :prerequisite_kind, uniqueness: { scope: %i[dependent_type dependent_id] }, allow_nil: true
      validate :dependent_is_purchasable
      validate :prerequisite_is_purchasable
      validate :exactly_one_prerequisite
      validate :same_platform
      validate :prerequisite_is_another_purchasable
      validate :no_cycle

      scope :for_dependent, ->(record) { where(dependent: record) }

      def holding? = %w[holding either].include?(met_by)
      def in_order? = %w[in_order either].include?(met_by)
      def revokes? = on_prerequisite_end == 'revoke'
      def kind? = prerequisite_kind.present?

      # What the buyer is told to get: the named purchasable, or the kind in words.
      def label
        return I18n.t("better_together.billing.purchase_requirements.kinds.#{prerequisite_kind}") if kind?

        prerequisite.purchasable_description
      end

      private

      def dependent_is_purchasable
        errors.add(:dependent_type, :not_purchasable) unless Purchasable.model_names.include?(dependent_type)
      end

      def prerequisite_is_purchasable
        return if prerequisite_type.blank? || Purchasable.model_names.include?(prerequisite_type)

        errors.add(:prerequisite_type, :not_purchasable)
      end

      def exactly_one_prerequisite
        errors.add(:base, :one_prerequisite) unless prerequisite_id.present? ^ prerequisite_kind.present?
      end

      def same_platform
        [dependent, prerequisite].compact.each do |side|
          errors.add(:base, :platform_owner_mismatch) if side.respond_to?(:platform_id) && side.platform_id != platform_id
        end
      end

      def prerequisite_is_another_purchasable
        errors.add(:prerequisite, :cannot_need_itself) if prerequisite && prerequisite == dependent
      end

      # Following specific prerequisites must never lead back to this rule's dependent.
      def no_cycle
        return unless prerequisite && dependent

        errors.add(:prerequisite, :cycle) if reaches?(prerequisite, dependent, Set.new)
      end

      def reaches?(from, target, seen)
        return false unless seen.add?([from.class.name, from.id])

        self.class.where(dependent: from).where.not(prerequisite_id: nil).includes(:prerequisite).any? do |rule|
          rule.prerequisite == target || reaches?(rule.prerequisite, target, seen)
        end
      end
    end
  end
end
