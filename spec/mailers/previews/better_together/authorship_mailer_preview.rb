# frozen_string_literal: true

module BetterTogether
  # Preview at /rails/mailers/better_together/authorship_mailer
  class AuthorshipMailerPreview < ActionMailer::Preview
    include FactoryBot::Syntax::Methods
    include BetterTogether::ApplicationHelper

    # Preview this email at
    # /rails/mailers/better_together/authorship_mailer/authorship_changed_notification
    def authorship_changed_notification
      host_platform || create(:platform, :host)

      actor = create(:user, :confirmed)
      recipient = create(:user, :confirmed)
      # Use build to avoid Elasticsearch callbacks on BetterTogether::Page
      page = build(:page)

      BetterTogether::AuthorshipMailer
        .with(page: page,
              recipient: recipient.person,
              action: 'added',
              actor_name: actor.person.name)
        .authorship_changed_notification
    end
  end
end
