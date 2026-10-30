# frozen_string_literal: true

module BetterTogether
  module Billing
    module PayExtensions
      # Binds Pay's records to a platform so one tenant's payment data can never
      # be read, written or re-pointed from another tenant.
      #
      # Included into Pay::Customer, Pay::Merchant, Pay::Charge, Pay::Subscription
      # and Pay::PaymentMethod (config/initializers/billing_pay_extensions.rb).
      #
      # * Customers and merchants take the platform from `Current.platform` during a
      #   web request or from an explicit `platform:`; otherwise they fail validation.
      # * Charges, subscriptions and payment methods copy their customer's platform
      #   and must match it (the database enforces the same with composite foreign
      #   keys, see the pay tables migration).
      # * An owner that is bound to one platform must be billed on that platform. An
      #   owner opts in by answering `billing_bound_platform_id` (a Community will,
      #   through Billing::Billable). People belong to no single platform for billing
      #   (one person can be a customer of several), so they do not answer it.
      # * The platform cannot change after create. Pay's own `set_payment_processor`
      #   looks up an owner's existing customer without regard to platform and then
      #   updates it, so without this a second platform could silently re-point the
      #   first platform's customer at itself.
      module PlatformScoping
        extend ActiveSupport::Concern

        included do
          include BetterTogether::Billing::PlatformBound

          before_validation :inherit_platform_from_parents, on: :create, prepend: true
          validate :platform_matches_parents
          validate :platform_matches_owner
        end

        private

        def parent_records
          %i[customer subscription].filter_map do |name|
            public_send(name) if self.class.reflect_on_association(name)
          end
        end

        def inherit_platform_from_parents
          return if platform_id.present?

          self.platform_id = parent_records.filter_map(&:platform_id).first
        end

        def platform_matches_parents
          return if platform_id.blank?

          parent_records.each do |parent|
            next if parent.platform_id == platform_id

            errors.add(:platform, :platform_parent_mismatch)
          end
        end

        def platform_matches_owner
          return if platform_id.blank? || !self.class.reflect_on_association(:owner)

          bound_platform_id = owner.try(:billing_bound_platform_id)
          return if bound_platform_id.blank? || bound_platform_id == platform_id

          errors.add(:platform, :platform_owner_mismatch)
        end
      end
    end
  end
end
