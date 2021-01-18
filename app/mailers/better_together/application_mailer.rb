module BetterTogether
  class ApplicationMailer < ActionMailer::Base
    default from: ENV.fetch(
      'DEFAULT_FROM_EMAIL',
      'community@bettertogethersolutions.com'
    )
    layout 'better_together/mailer'
  end
end
