# frozen_string_literal: true

module BetterTogether
  # Base mailer for the engine
  class ApplicationMailer < ActionMailer::Base
    default from: ENV.fetch(
      'DEFAULT_FROM_EMAIL',
      'community@bettertogethersolutions.com'
    )
    layout 'better_together/mailer'
  end
end
