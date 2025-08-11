# frozen_string_literal: true

module BetterTogether
  # Sends notifications related to Joatu matchmaking
  class JoatuMailer < ApplicationMailer
    def new_match(recipient, offer:, request:)
      @offer = offer
      @request = request
      @recipient = recipient

      mail(to: recipient.email, subject: 'New Joatu match')
    end
  end
end
