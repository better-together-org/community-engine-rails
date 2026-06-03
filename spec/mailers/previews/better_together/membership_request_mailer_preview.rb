# frozen_string_literal: true

module BetterTogether # :nodoc:
  # Preview at /rails/mailers/better_together/membership_request_mailer
  class MembershipRequestMailerPreview < ActionMailer::Preview
    include FactoryBot::Syntax::Methods

    # Preview at /rails/mailers/better_together/membership_request_mailer/submitted_to_reviewer
    def submitted_to_reviewer
      community = ensure_host_community
      membership_request = create(
        :better_together_joatu_membership_request,
        target: community,
        requestor_name: 'Alex Applicant',
        requestor_email: 'alex.applicant@example.test'
      )
      reviewer = create(:person)

      BetterTogether::MembershipRequestMailer.with(
        membership_request:,
        recipient: reviewer,
        review_url: review_url_for(community, membership_request)
      ).submitted
    end

    # Preview at /rails/mailers/better_together/membership_request_mailer/declined_for_email_requester
    def declined_for_email_requester
      community = ensure_host_community
      membership_request = declined_request_for(community)

      BetterTogether::MembershipRequestMailer.with(
        membership_request:,
        recipient: preview_recipient_for(membership_request),
        review_url: BetterTogether::Engine.routes.url_helpers.community_url(community, locale: I18n.default_locale)
      ).declined
    end

    private

    def ensure_host_community
      BetterTogether::Community.find_by(host: true) || create(:community, :host)
    end

    def declined_request_for(community)
      create(
        :better_together_joatu_membership_request,
        target: community,
        requestor_name: 'Alex Applicant',
        requestor_email: 'alex.applicant@example.test',
        status: 'closed'
      )
    end

    def preview_recipient_for(membership_request)
      {
        email: membership_request.requestor_email,
        locale: I18n.default_locale,
        time_zone: Time.zone.to_s,
        name: membership_request.requestor_name
      }
    end

    def review_url_for(community, membership_request)
      BetterTogether::Engine.routes.url_helpers.community_membership_request_url(
        community,
        membership_request,
        locale: I18n.default_locale
      )
    end
  end
end
