# frozen_string_literal: true

module BetterTogether
  module Billing
    module MerchantAccounts
      module StripeConnect
        # Creates or reuses a Stripe Connect account and returns an onboarding link.
        class CreateOnboardingLink
          class Error < StandardError; end
          class OnboardingDisabledError < Error; end

          Result = Struct.new(
            :merchant_account,
            :stripe_account,
            :account_link,
            :created,
            keyword_init: true
          ) do
            delegate :url, to: :account_link
          end

          def call(owner:, refresh_url:, return_url:, type: 'account_onboarding')
            raise OnboardingDisabledError, 'Merchant onboarding is disabled.' unless merchant_account_class.onboarding_enabled?

            merchant_account = merchant_account_for(owner)
            created = merchant_account.new_record?
            stripe_account = provision_stripe_account(owner)
            sync_result = sync_service.call(merchant_account:, owner:, stripe_account:)

            build_result(sync_result, refresh_url:, return_url:, type:, created:)
          end

          private

          def merchant_account_class
            BetterTogether::Billing::MerchantAccount
          end

          def merchant_account_for(owner)
            merchant_account_class.find_or_initialize_by(
              owner:,
              provider: 'stripe_connect'
            )
          end

          def provision_stripe_account(owner)
            merchant_processor = owner.merchant_processor || owner.set_merchant_processor(:stripe)
            return merchant_processor.account if merchant_processor.processor_id.present?

            merchant_processor.create_account(**stripe_account_attributes(owner))
          end

          def build_result(sync_result, refresh_url:, return_url:, type:, created:)
            Result.new(
              merchant_account: sync_result.merchant_account,
              stripe_account: sync_result.stripe_account,
              account_link: create_account_link(sync_result.merchant_account, refresh_url:, return_url:, type:),
              created:
            )
          end

          def stripe_account_attributes(owner)
            base_attributes(owner).tap do |attrs|
              email = owner_email(owner)
              attrs[:email] = email if email.present?
            end
          end

          def base_attributes(owner)
            {
              country: owner_country(owner),
              business_type: stripe_business_type(owner),
              controller: stripe_controller_attributes,
              capabilities: stripe_capabilities,
              business_profile: { name: owner.to_s },
              metadata: stripe_metadata(owner)
            }
          end

          def stripe_controller_attributes
            {
              dashboard: { type: 'express' },
              fees: { payer: 'application' },
              losses: { payments: 'application' },
              stripe_dashboard: { type: 'express' }
            }
          end

          def stripe_capabilities
            {
              card_payments: { requested: true },
              transfers: { requested: true }
            }
          end

          def stripe_metadata(owner)
            {
              bt_owner_type: owner.class.name,
              bt_owner_id: owner.id
            }
          end

          def stripe_business_type(owner)
            owner.is_a?(BetterTogether::Person) ? 'individual' : 'company'
          end

          def owner_country(owner)
            owner.try(:country).presence || 'CA'
          end

          def owner_email(owner)
            owner.try(:email).presence || owner.try(:creator).try(:email).presence
          end

          def create_account_link(merchant_account, refresh_url:, return_url:, type:)
            merchant_account.owner.merchant_processor.account_link(
              refresh_url:,
              return_url:,
              type:
            )
          end

          def sync_service
            @sync_service ||= BetterTogether::Billing::MerchantAccounts::StripeConnect::SyncAccount.new
          end
        end
      end
    end
  end
end
