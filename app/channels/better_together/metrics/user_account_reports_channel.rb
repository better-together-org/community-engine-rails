# frozen_string_literal: true

module BetterTogether
  module Metrics
    # Action Cable channel for user account report file generation updates
    class UserAccountReportsChannel < ApplicationCable::Channel
      def subscribed
        stream_for current_person
      end

      def unsubscribed
        # Any cleanup needed when channel is unsubscribed
      end
    end
  end
end
