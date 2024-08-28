# frozen_string_literal: true

module BetterTogether
  class MailerJob < ApplicationJob
    queue_as :mailer
  end
end
