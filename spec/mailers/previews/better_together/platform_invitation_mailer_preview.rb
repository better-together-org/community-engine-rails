# spec/mailers/previews/better_together/platform_invitation_mailer_preview.rb
require 'factory_bot_rails'

module BetterTogether
  class PlatformInvitationMailerPreview < ActionMailer::Preview
    include FactoryBot::Syntax::Methods

    def invite
      platform = create(:platform, name: "Example Platform")
      platform_invitation = build(:platform_invitation,
                                  invitee_email: "test@example.com",
                                  invitable: platform,
                                  valid_from: Time.zone.now,
                                  token: "example_token")

      BetterTogether::PlatformInvitationMailer.with(platform_invitation: platform_invitation).invite(platform_invitation)
    end
  end
end
