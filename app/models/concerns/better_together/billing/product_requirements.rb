# frozen_string_literal: true

module BetterTogether
  module Billing
    # What a product needs of a buyer, as a steward edits it on the product form: tick the plans it goes with, or "any plan",
    # and leave all unticked to sell it on its own. Stored as purchase requirements on the product, so the rules screen and
    # the checkout read the same rows. A product with no rule is open to everyone.
    module ProductRequirements
      extend ActiveSupport::Concern

      included do
        has_many :purchase_requirements, as: :dependent, class_name: 'BetterTogether::Billing::PurchaseRequirement', dependent: :destroy
        after_save :apply_requirement_edits
      end

      PARAMS = [:needs_any_plan, { needed_plan_ids: [] }].freeze

      def needs_any_plan = @needs_any_plan.nil? ? purchase_requirements.any?(&:kind?) : @needs_any_plan
      alias needs_any_plan? needs_any_plan

      def needed_plan_ids
        @needed_plan_ids || purchase_requirements.select { |rule| rule.prerequisite_type == Plan.polymorphic_name }.map(&:prerequisite_id)
      end

      def needs_any_plan=(value)
        @needs_any_plan = ActiveModel::Type::Boolean.new.cast(value) || false
        @requirements_edited = true
      end

      def needed_plan_ids=(ids)
        @needed_plan_ids = Array(ids).compact_blank.map(&:to_s)
        @requirements_edited = true
      end

      private

      # Only plans this platform sells itself can be asked for; anything else is ignored.
      def apply_requirement_edits
        return unless @requirements_edited

        wanted_ids = Plan.where(platform_id:, id: needed_plan_ids).sold_by_platform.pluck(:id)
        remove_unwanted_requirements(wanted_ids)
        add_missing_requirements(wanted_ids)
        @requirements_edited = @needs_any_plan = @needed_plan_ids = nil
        purchase_requirements.reset
      end

      def remove_unwanted_requirements(wanted_ids)
        purchase_requirements.reload.each do |rule|
          rule.destroy! unless (rule.kind? && needs_any_plan) || wanted_ids.include?(rule.prerequisite_id)
        end
      end

      def add_missing_requirements(wanted_ids)
        have = purchase_requirements.reload
        purchase_requirements.create!(platform_id:, prerequisite_kind: 'plan', met_by: 'either') if needs_any_plan && have.none?(&:kind?)
        (wanted_ids - have.map(&:prerequisite_id)).each do |plan_id|
          purchase_requirements.create!(platform_id:, prerequisite_type: Plan.polymorphic_name, prerequisite_id: plan_id, met_by: 'either')
        end
      end
    end
  end
end
