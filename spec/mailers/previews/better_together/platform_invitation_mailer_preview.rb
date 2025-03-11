# frozen_string_literal: true

# spec/mailers/previews/better_together/platform_invitation_mailer_preview.rb
require 'factory_bot_rails'

module BetterTogether
  class PlatformInvitationMailerPreview < ActionMailer::Preview
    include FactoryBot::Syntax::Methods

    def invite
      platform = create(:platform)
      platform_invitation = build(:platform_invitation, :greeting,
                                  invitable: platform)

      BetterTogether::PlatformInvitationMailer.with(platform_invitation:).invite(platform_invitation)
    end
  end
end
