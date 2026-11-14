# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::BlockAwareInvitation do # rubocop:disable RSpec/SpecFilePathFormat
  let(:inviter) { create(:better_together_person) }
  let(:target_user) { create(:better_together_user, :confirmed) }
  let(:target) { target_user.person }
  let(:community) { create(:better_together_community) }

  def community_invitation(**attrs)
    build(:better_together_invitation, invitable: community, inviter:, **attrs)
  end

  def platform_invitation(**attrs)
    build(:platform_invitation, inviter:, **attrs)
  end

  before { configure_host_platform }

  it 'allows invitations without a block', :aggregate_failures do
    expect(community_invitation(invitee: target, invitee_email: nil)).to be_valid
    expect(community_invitation(invitee: nil, invitee_email: target_user.email)).to be_valid
  end

  context 'when the inviter blocked the target' do
    before { create(:person_block, blocker: inviter, blocked: target) }

    it 'rejects a person invitation' do
      invitation = community_invitation(invitee: target, invitee_email: nil)

      expect(invitation).not_to be_valid
    end

    it 'rejects an email invitation to the same person' do
      invitation = community_invitation(invitee: nil, invitee_email: target_user.email)

      expect(invitation).not_to be_valid
    end

    it 'rejects a platform invitation by email' do
      expect(platform_invitation(invitee_email: target_user.email)).not_to be_valid
    end
  end

  context 'when the target blocked the inviter' do
    before { create(:person_block, blocker: target, blocked: inviter) }

    it 'rejects person and email invitations', :aggregate_failures do
      expect(community_invitation(invitee: target, invitee_email: nil)).not_to be_valid
      expect(community_invitation(invitee: nil, invitee_email: target_user.email.upcase)).not_to be_valid
      expect(platform_invitation(invitee_email: target_user.email)).not_to be_valid
    end
  end

  it 'does not block emails that belong to no existing person' do
    create(:person_block, blocker: inviter, blocked: target)

    expect(community_invitation(invitee: nil, invitee_email: 'stranger@example.test')).to be_valid
  end
end
