# frozen_string_literal: true

module BetterTogether # :nodoc:
  # Preview at /rails/mailers/better_together/community_invitations_mailer
  class CommunityInvitationsMailerPreview < ActionMailer::Preview
    include FactoryBot::Syntax::Methods

    # Preview at /rails/mailers/better_together/community_invitations_mailer/invite
    def invite
      community = BetterTogether::Community.find_by(host: true) || create(:community, :host)
      invitation = create(
        :better_together_community_invitation,
        invitable: community,
        invitee_email: 'alex.applicant@example.test'
      )

      BetterTogether::CommunityInvitationsMailer.with(
        invitation: invitation,
        invitable: invitation.invitable
      ).invite
    end
  end
end
