# frozen_string_literal: true

module BetterTogether
  # action cable channel for notifications
  class NotificationsChannel < ApplicationCable::Channel
    def subscribed
      stream_for current_person
    end

    def unsubscribed
      # Any cleanup needed when channel is unsubscribed
    end
  end
end
