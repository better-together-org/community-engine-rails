# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Notifies creators when a new offer or request matches
    class MatchNotifier < ApplicationNotifier
      deliver_by :action_cable, channel: 'BetterTogether::NotificationsChannel', message: :build_message
      deliver_by :email, mailer: 'BetterTogether::JoatuMailer', method: :new_match, params: :email_params

      param :offer, :request

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
    end
  end
end
