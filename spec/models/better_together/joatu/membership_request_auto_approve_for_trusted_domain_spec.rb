# frozen_string_literal: true

require 'rails_helper'

# A request from a trusted domain skips the pending state; anyone else still waits for a reviewer.
RSpec.describe BetterTogether::Joatu::MembershipRequest, '#auto_approve_for_trusted_domain' do
  let!(:platform) { configure_host_platform }
  let(:community) { platform.community }
  let(:domain_role) { BetterTogether::Role.find_by!(identifier: 'community_member') }
  let(:notification_service) { instance_double(BetterTogether::MembershipRequestNotificationService, notify_submission: nil, notify_approval: nil) }

  before do
    manager = create(:better_together_person)
    platform.person_platform_memberships.create!(member: manager, status: 'active',
                                                 role: BetterTogether::Role.find_by!(identifier: 'platform_manager'))
    create(:platform_trusted_domain, platform:, domain: 'trusted.example', role: domain_role)
    allow(BetterTogether::MembershipRequestNotificationService).to receive(:new).and_return(notification_service)
  end

  def submit(*traits, **attrs)
    create(:better_together_joatu_membership_request, *traits, target: community, **attrs)
  end

  context 'without an account' do
    it 'approves a trusted-domain request and sends an invitation instead of notifying reviewers', :aggregate_failures do
      request = submit(requestor_email: 'ann@trusted.example')

      expect(request.reload.status).to eq('fulfilled')
      expect(BetterTogether::CommunityInvitation.find_by(invitable: community, invitee_email: 'ann@trusted.example'))
        .to have_attributes(role: domain_role)
      expect(notification_service).not_to have_received(:notify_submission)
      expect(BetterTogether::TrustedDomainEvent.last).to have_attributes(event_type: 'membership_request_approved',
                                                                         via: 'membership_request')
    end

    it 'leaves other requests open for review', :aggregate_failures do
      request = submit(requestor_email: 'bob@elsewhere.example')

      expect(request.reload.status).to eq('open')
      expect(notification_service).to have_received(:notify_submission)
      expect(BetterTogether::TrustedDomainEvent.count).to eq(0)
    end
  end

  context 'with an account' do
    it 'activates the membership at once for a confirmed trusted-domain account', :aggregate_failures do
      person = create(:better_together_user, email: 'cy@trusted.example', confirmed_at: Time.current).person
      request = submit(:with_creator, creator: person)

      expect(request.reload.status).to eq('fulfilled')
      expect(community.person_community_memberships.find_by(member: person)).to have_attributes(status: 'active')
    end

    it 'does not trust an unconfirmed account address', :aggregate_failures do
      person = create(:better_together_user, email: 'di@trusted.example', confirmed_at: nil).person
      request = submit(:with_creator, creator: person)

      expect(request.reload.status).to eq('open')
      expect(community.person_community_memberships.find_by(member: person)&.status).not_to eq('active')
    end
  end

  it 'does nothing for a community that is not a platform primary community' do
    other = create(:better_together_community)
    request = create(:better_together_joatu_membership_request, target: other, requestor_email: 'ann@trusted.example')

    expect(request.reload.status).to eq('open')
  end
end
