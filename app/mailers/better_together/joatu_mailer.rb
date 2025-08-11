# frozen_string_literal: true

module BetterTogether
  # Sends Joatu related emails
  class JoatuMailer < ApplicationMailer
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
