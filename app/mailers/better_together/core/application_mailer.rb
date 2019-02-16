module BetterTogether
  module Core
    class ApplicationMailer < ActionMailer::Base
      default from: 'from@example.com'
      layout 'mailer'
    end
  end
end
