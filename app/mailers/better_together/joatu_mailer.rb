# frozen_string_literal: true

module BetterTogether
  # Sends notifications related to Joatu matchmaking
  class JoatuMailer < ApplicationMailer
    # Support both direct delivery (recipient, offer:, request:) and
    # Noticed delivery using `.with(offer:, request:, recipient:)`.
    def new_match(recipient = nil, *_args, offer: nil, request: nil, **kwargs)
      # Accept various call shapes from Noticed or direct invocation.
      @recipient = recipient || kwargs[:recipient] || params[:recipient]
      @offer = offer || kwargs[:offer] || params[:offer]
      @request = request || kwargs[:request] || params[:request]

      mail(to: @recipient.email, subject: 'New Joatu match')
    end

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

    def agreement_status_changed
      @platform = BetterTogether::Platform.find_by(host: true)
      @agreement = params[:agreement]
      @recipient = params[:recipient]
      @status = @agreement.status

      self.locale = @recipient.locale if @recipient.respond_to?(:locale)
      self.time_zone = @recipient.time_zone if @recipient.respond_to?(:time_zone)

      subject = "Agreement #{@status}"

      mail(to: @recipient.email, subject:, template_name: "agreement_status_changed_#{@status}")
    end
  end
end
