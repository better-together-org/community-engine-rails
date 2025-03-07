# frozen_string_literal: true

module BetterTogether
  # Ensures that all mailer jobs use the mailer queue and other common configurations
  class MailerJob < ApplicationJob
    queue_as :mailers
  end
end
