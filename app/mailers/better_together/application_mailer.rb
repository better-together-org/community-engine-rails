module BetterTogether
  class ApplicationMailer < ActionMailer::Base
    default from: ENV.fetch(
      'DEFAULT_FROM_EMAIL',
      'info@bettertogethersolutions.com'
    )
    layout 'mailer'
  end
end
