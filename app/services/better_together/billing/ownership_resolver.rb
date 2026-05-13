# frozen_string_literal: true

module BetterTogether
  module Billing
    # Helpers for building Stripe checkout metadata and resolving billing
    # record owners from Stripe webhook payloads.
    #
    # With v1 owner-equals-beneficiary, metadata only needs to encode the
    # billing plan. The billable owner is implicit from the Pay::Customer
    # associated with the Stripe customer ID on the webhook payload.
    module OwnershipResolver
      SUPPORTED_OWNER_TYPES = {
        'community' => 'BetterTogether::Community',
        'person' => 'BetterTogether::Person',
        'BetterTogether::Community' => 'BetterTogether::Community',
        'BetterTogether::Person' => 'BetterTogether::Person',
        'Community' => 'BetterTogether::Community',
        'Person' => 'BetterTogether::Person'
      }.freeze

      module_function

      # Builds Stripe checkout metadata encoding the billing plan only.
      # Owner identity is implicit from which pay_customer calls checkout.
      def build_metadata(billing_plan:)
        {
          bt_billing_plan_id: billing_plan.id,
          bt_billing_plan_identifier: billing_plan.identifier
        }
      end

      # Resolves the billable owner from the Stripe webhook payload.
      # Falls back to the pay_customer owner when metadata lacks an explicit type.
      def resolve_billable_owner(metadata:, fallback_owner: nil)
        resolve_record(metadata['bt_billable_owner_type'], metadata['bt_billable_owner_id']) ||
          resolve_record('BetterTogether::Community', metadata['bt_community_id']) ||
          fallback_owner
      end

      def supported_owner_type?(record)
        record.present? && SUPPORTED_OWNER_TYPES.value?(record.class.name)
      end

      def supported_owner_type_name(type_name)
        SUPPORTED_OWNER_TYPES[type_name.to_s]
      end

      def resolve_record(type_name, id)
        normalized_type = supported_owner_type_name(type_name)
        return if normalized_type.blank? || id.blank?

        normalized_type.constantize.find_by(id:)
      rescue NameError
        nil
      end
    end
  end
end
