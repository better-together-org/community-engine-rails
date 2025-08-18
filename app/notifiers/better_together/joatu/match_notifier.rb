# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Notifies creators when a new offer or request matches
    class MatchNotifier < ApplicationNotifier
      deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message
      deliver_by :email, mailer: 'BetterTogether::JoatuMailer', method: :new_match, params: :email_params

      param :offer, :request

      notification_methods do
        delegate :offer, :request, to: :event
      end

      def offer = params[:offer]
      def request = params[:request]

      def title
        'New match found'
      end

      def body
        "#{offer.name} matches #{request.name}"
      end

      def build_message(_notification)
        { title:, body: }
      end

      def email_params(_notification)
        { offer:, request: }
      end

      # Ensure immediate delivery in tests and synchronous contexts
      # without relying on the ActiveJob test adapter.
      def deliver_now(recipient)
        BetterTogether::JoatuMailer
          .with(offer:, request:, recipient: recipient)
          .new_match
          .deliver_now

        # Also trigger the standard delivery flow (creates Noticed notification,
        # action cable, etc.). This will enqueue jobs under test adapter,
        # which is fine since we've already sent the email synchronously.
        super
      end
    end
  end
end
