# frozen_string_literal: true

module BetterTogether
  module Billing
    # Shared resolution helpers for billing owner and beneficiary metadata.
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

      def build_metadata(billable_owner:, beneficiary:)
        {
          bt_billable_owner_type: billable_owner.class.name,
          bt_billable_owner_id: billable_owner.id,
          bt_beneficiary_type: beneficiary.class.name,
          bt_beneficiary_id: beneficiary.id
        }.merge(legacy_community_metadata(beneficiary))
      end

      def resolve_billable_owner(metadata:, fallback_owner: nil)
        resolve_record(metadata['bt_billable_owner_type'], metadata['bt_billable_owner_id']) ||
          resolve_record('BetterTogether::Community', metadata['bt_community_id']) ||
          fallback_owner
      end

      def resolve_beneficiary(metadata:, fallback_beneficiary: nil, billable_owner: nil)
        resolve_record(metadata['bt_beneficiary_type'], metadata['bt_beneficiary_id']) ||
          resolve_record('BetterTogether::Community', metadata['bt_community_id']) ||
          fallback_beneficiary ||
          billable_owner
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

      def legacy_community_metadata(record)
        return {} unless record.is_a?(BetterTogether::Community)

        {
          bt_community_id: record.id,
          bt_community_identifier: record.identifier
        }
      end
    end
  end
end
