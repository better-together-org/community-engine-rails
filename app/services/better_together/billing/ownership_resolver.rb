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
      module_function

      # Open extension point (docs/developers/architecture/
      # polymorphic_allowlist_extension_audit.md) — any model that includes
      # Billing::Billable (payer) or Billing::SponsorshipRecipient
      # (beneficiary) is resolvable here, instead of a hand-maintained list.
      # Built fresh per call rather than memoized: this mirrors Sponsorship's
      # own validation, and avoids stale results if a host app adds a new
      # includer without a full app restart in dev/test.
      def owner_type_aliases
        supported_owner_types.each_with_object({}) do |name, aliases|
          short_name = name.demodulize
          aliases[name] = name
          aliases[short_name] = name
          aliases[short_name.underscore] = name
        end
      end

      def supported_owner_types
        (Billable.included_in_models + SponsorshipRecipient.included_in_models).map(&:name).uniq
      end

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
        record.present? && supported_owner_types.include?(record.class.name)
      end

      def supported_owner_type_name(type_name)
        owner_type_aliases[type_name.to_s]
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
