# frozen_string_literal: true

module BetterTogether
  module Billing
    # A hosted platform's billing standing with the host: active, or suspended by the host. Created when the host first acts on it.
    # What the platform has agreed to is held as agreement acceptances (see Billing::HostedBilling), never here.
    class HostedAccount < ApplicationRecord
      include PlatformBound

      self.table_name = 'better_together_billing_hosted_accounts'

      STATUSES = %w[active suspended].freeze

      belongs_to :suspended_by, class_name: 'BetterTogether::Person', optional: true

      validates :status, inclusion: { in: STATUSES }
      validates :platform_id, uniqueness: true
      validates :suspension_reason, presence: true, if: -> { status == 'suspended' }
      validate :not_the_host

      def suspended? = status == 'suspended'

      private

      def not_the_host
        errors.add(:platform, :cannot_be_the_host) if platform&.host?
      end
    end
  end
end
