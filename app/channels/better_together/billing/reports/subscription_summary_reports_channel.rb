# frozen_string_literal: true

module BetterTogether
  module Billing
    module Reports
      # Action Cable channel for subscription summary report file generation updates.
      class SubscriptionSummaryReportsChannel < ApplicationCable::Channel
        def subscribed
          stream_for current_person
        end

        def unsubscribed
          # no cleanup needed
        end
      end
    end
  end
end
