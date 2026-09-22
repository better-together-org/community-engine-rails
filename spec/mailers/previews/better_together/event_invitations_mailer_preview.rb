# frozen_string_literal: true

module BetterTogether # :nodoc:
  # Preview at /rails/mailers/better_together/event_invitations_mailer
  class EventInvitationsMailerPreview < ActionMailer::Preview
    include FactoryBot::Syntax::Methods

    # Preview at /rails/mailers/better_together/event_invitations_mailer/invite
    def invite # rubocop:todo Metrics/MethodLength
      platform = BetterTogether::Platform.find_by(host: true)
      event = create(
        :better_together_event,
        platform: platform,
        name: 'Community Invitation Review Session'
      )
      invitation = create(
        :better_together_event_invitation,
        invitable: event,
        invitee_email: 'alex.applicant@example.test'
      )

      BetterTogether::EventInvitationsMailer.with(
        invitation: invitation,
        invitable: invitation.invitable
      ).invite
    end
  end
end
