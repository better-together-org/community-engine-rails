# frozen_string_literal: true

module BetterTogether
  module Billing
    # How often something is billed and how a renewal is handled: the interval (`month`, `year`, or `one_time` until
    # PS-6 moves one-off sales out), how many of them make a period, the grace days a lapsed renewal keeps working and
    # the lead days before a period ends that its invoice is made. Needs the columns `billing_interval`, `interval_count`,
    # `grace_days` and `renewal_lead_days`. Only recurring sales use the renewal settings.
    module SubscriptionTerms
      extend ActiveSupport::Concern

      BILLING_INTERVALS = %w[month year one_time].freeze
      MAX_GRACE_DAYS = 90
      MAX_LEAD_DAYS = 60
      # How a subscription is renewed by Community Engine (a method outside a processor): the days it keeps working
      # after a period ends unpaid, and how many days before a period ends its invoice is made.
      # Not held by any processor, so editable at any time; a change applies from the next renewal.
      RENEWAL_FIELDS = %i[grace_days renewal_lead_days].freeze

      included do
        validates :billing_interval, inclusion: { in: BILLING_INTERVALS }
        validates :interval_count, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 36 }
        validate :one_time_has_a_single_period
        validates :grace_days, numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_GRACE_DAYS }
        validates :renewal_lead_days, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: MAX_LEAD_DAYS }
      end

      def recurring?
        billing_interval.in?(%w[month year])
      end

      def launch_ready_for_hosted_billing?
        recurring?
      end

      private

      def one_time_has_a_single_period
        errors.add(:interval_count, :one_time_single) if billing_interval == 'one_time' && interval_count != 1
      end
    end
  end
end
