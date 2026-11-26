# frozen_string_literal: true

module BetterTogether
  module Billing
    # What a plan says about how a subscription to it runs: the days an unpaid period may stay unpaid before the subscription lapses
    # (`grace_days`), and how long before a period ends its renewal invoice is issued (`renewal_lead_days`). How often it renews
    # belongs to the price it is bought through (see Price#interval).
    module SubscriptionTerms
      extend ActiveSupport::Concern

      BILLING_INTERVALS = Price::INTERVALS
      MAX_GRACE_DAYS = 90
      MAX_LEAD_DAYS = 60
      RENEWAL_FIELDS = %i[grace_days renewal_lead_days].freeze

      included do
        validates :billing_interval, inclusion: { in: BILLING_INTERVALS }
        validates :interval_count, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 36 }
        validates :grace_days, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_GRACE_DAYS }
        validates :renewal_lead_days, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_LEAD_DAYS }
      end

      def recurring?
        billing_interval.in?(BILLING_INTERVALS)
      end

      def launch_ready_for_hosted_billing?
        recurring?
      end
    end
  end
end
