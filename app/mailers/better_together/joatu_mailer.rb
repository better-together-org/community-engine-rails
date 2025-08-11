# frozen_string_literal: true

module BetterTogether
  # Sends Joatu related emails
  class JoatuMailer < ApplicationMailer
    def agreement_created
      @agreement = params[:agreement]
      @offer = @agreement.offer
      @request = @agreement.request
      @recipient = params[:recipient]
      @platform = BetterTogether::Platform.find_by(host: true)

      self.locale = @recipient.locale
      self.time_zone = @recipient.time_zone

      mail(to: @recipient.email, subject: t('.subject'))
    end
  end
end
