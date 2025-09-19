# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Notifies creators when a new offer or request matches
    class MatchNotifier < ApplicationNotifier
      deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message,
                                queue: :notifications do |config|
        config.if = -> { should_notify? }
      end
      deliver_by :email, mailer: 'BetterTogether::JoatuMailer', method: :new_match, params: :email_params,
                         queue: :mailers do |config|
        config.if = -> { recipient_has_email? && should_notify? }
      end

      required_param :offer, :request

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

      notification_methods do
        def current_offer_gid
          offer.respond_to?(:to_global_id) ? offer.to_global_id.to_s : offer.to_s
        end

        def current_request_gid
          request.respond_to?(:to_global_id) ? request.to_global_id.to_s : request.to_s
        end

        def recipient_has_email?
          recipient.respond_to?(:email) && recipient.email.present? &&
            (!recipient.respond_to?(:notification_preferences) || recipient.notification_preferences['notify_by_email'])
        end

        # Avoid duplicate unread notifications for the same offer/request pair per recipient
        def should_notify? # rubocop:todo Metrics/AbcSize
          unread = recipient.notifications.unread.includes(:event)
          o_gid = current_offer_gid
          r_gid = current_request_gid
          unread.none? do |notification|
            ev = notification.event
            next false unless ev.is_a?(BetterTogether::Joatu::MatchNotifier)

            params = ev.respond_to?(:params) ? ev.params : {}
            params['offer'].to_s == o_gid && params['request'].to_s == r_gid
          end
        end
      end

      # Prevent creating a new notification record if an unread one exists for this pair
      def deliver(recipient)
        return if duplicate_for?(recipient)

        super
      end

      private

      def duplicate_for?(recipient)
        unread = recipient.notifications.unread.includes(:event)
        unread.any? do |notification|
          ev = notification.event
          next false unless ev.is_a?(BetterTogether::Joatu::MatchNotifier)

          begin
            ev.offer&.id == offer.id && ev.request&.id == request.id
          rescue StandardError
            false
          end
        end
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
