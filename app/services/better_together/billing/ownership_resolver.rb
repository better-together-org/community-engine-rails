# frozen_string_literal: true

module BetterTogether
  module Billing
    # Helpers for building Stripe checkout metadata and resolving billing
    # record owners from Stripe webhook payloads.
    #
    # Hosted billing needs both the paying owner and the beneficiary encoded so
    # sponsored checkouts can be reconstructed after hosted redirects and
    # webhook delivery.
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

      # Builds Stripe checkout metadata for the billing plan plus any explicit
      # owner / beneficiary split used by sponsored hosted billing flows.
      def build_metadata(billing_plan:, billable_owner: nil, beneficiary: nil)
        metadata = {
          bt_billing_plan_id: billing_plan.id,
          bt_billing_plan_identifier: billing_plan.identifier
        }

        if supported_owner_type?(billable_owner)
          metadata[:bt_billable_owner_type] = billable_owner.class.name
          metadata[:bt_billable_owner_id] = billable_owner.id
        end

        if supported_owner_type?(beneficiary)
          metadata[:bt_beneficiary_type] = beneficiary.class.name
          metadata[:bt_beneficiary_id] = beneficiary.id
        end

        metadata
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
