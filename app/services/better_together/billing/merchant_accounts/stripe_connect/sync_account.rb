# frozen_string_literal: true

module BetterTogether
  module Billing
    module MerchantAccounts
      module StripeConnect
        # Maps Stripe Connect account state into the local merchant account read model.
        class SyncAccount
          class Error < StandardError; end

          Result = Struct.new(
            :merchant_account,
            :stripe_account,
            :created,
            keyword_init: true
          )

          def call(merchant_account: nil, owner: nil, stripe_account: nil, stripe_account_id: nil)
            account = stripe_account || retrieve_account(stripe_account_id || merchant_account&.external_account_id)
            local_merchant_account = merchant_account || find_or_initialize_account(owner:, stripe_account: account)
            created = local_merchant_account.new_record?

            local_merchant_account.assign_attributes(attributes_from(account))
            local_merchant_account.owner ||= owner
            local_merchant_account.provider ||= 'stripe_connect'
            local_merchant_account.save!

            Result.new(
              merchant_account: local_merchant_account,
              stripe_account: account,
              created:
            )
          end

          private

          def retrieve_account(account_id)
            raise Error, 'Stripe account id is required.' if account_id.blank?

            Stripe::Account.retrieve(account_id)
          end

          def find_or_initialize_account(owner:, stripe_account:)
            raise Error, 'Owner is required for a new merchant account.' if owner.blank?

            BetterTogether::Billing::MerchantAccount.find_or_initialize_by(
              owner:,
              provider: 'stripe_connect'
            ).tap do |merchant_account|
              merchant_account.external_account_id ||= stripe_account.id
            end
          end

          def attributes_from(account)
            {
              external_account_id: account.id,
              status: map_status(account),
              charges_enabled: cast_bool(account.charges_enabled),
              payouts_enabled: cast_bool(account.payouts_enabled),
              country: account.country.presence,
              currency: account.default_currency.to_s.upcase.presence,
              capabilities: normalize_capabilities(account.capabilities),
              metadata: normalize_metadata(account),
              last_synced_at: Time.current
            }
          end

          def map_status(account)
            return 'disabled' if account.respond_to?(:deleted) && cast_bool(account.deleted)
            return 'restricted' if requirements_due?(account)
            return 'active' if cast_bool(account.charges_enabled) && cast_bool(account.payouts_enabled)
            return 'pending' unless cast_bool(account.details_submitted)

            'onboarding'
          end

          def requirements_due?(account)
            requirement_field_values(account).any?(&:any?)
          end

          def normalize_capabilities(capabilities)
            return {} unless capabilities.respond_to?(:to_h)

            capabilities.to_h.transform_values(&:to_s)
          end

          def normalize_metadata(account)
            {
              details_submitted: cast_bool(account.details_submitted),
              business_type: account.business_type.presence,
              default_currency: account.default_currency.to_s.upcase.presence,
              requirements: normalized_requirements(account),
              charges_enabled: cast_bool(account.charges_enabled),
              payouts_enabled: cast_bool(account.payouts_enabled)
            }.compact
          end

          def normalized_requirements(account)
            requirements = account.try(:requirements)

            {
              currently_due: compact_requirement_value(requirements, :currently_due),
              eventually_due: compact_requirement_value(requirements, :eventually_due),
              past_due: compact_requirement_value(requirements, :past_due),
              pending_verification: compact_requirement_value(requirements, :pending_verification),
              disabled_reason: requirements.try(:disabled_reason).presence
            }.compact
          end

          def requirement_field_values(account)
            requirements = account.try(:requirements)

            %i[currently_due eventually_due past_due pending_verification].map do |field|
              compact_requirement_value(requirements, field)
            end
          end

          def compact_requirement_value(requirements, field)
            Array(requirements.try(field)).compact
          end

          def cast_bool(value)
            ActiveModel::Type::Boolean.new.cast(value)
          end
        end
      end
    end
  end
end
