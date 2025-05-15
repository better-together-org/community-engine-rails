# frozen_string_literal: true

# spec/mailers/previews/better_together/platform_invitation_mailer_preview.rb
# <APP_HOST>/rails/mailers/better_together/platform_invitation_mailer to preview
require 'factory_bot_rails'

module BetterTogether
  class PlatformInvitationMailerPreview < ActionMailer::Preview
    include FactoryBot::Syntax::Methods
    include BetterTogether::ApplicationHelper

    def invite
      platform = host_platform || create(:platform)
      platform_invitation = create(:platform_invitation,
                                   invitable: platform)

      BetterTogether::PlatformInvitationMailer.with(platform_invitation:).invite(platform_invitation)
    end
  end
end
