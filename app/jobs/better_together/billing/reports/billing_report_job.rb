# frozen_string_literal: true

module BetterTogether
  module Billing
    module Reports
      class BillingReportJob < ApplicationJob # rubocop:todo Style/Documentation
        queue_as :billing_reports
      end
    end
  end
end
