# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::InvitationSessionManagement do
  let(:includer) do
    Class.new do
      include BetterTogether::InvitationSessionManagement

      def helpers
        nil
      end
    end.new
  end

  describe '#resolve_invitation_platform' do
    it "returns a community invitation's community's platform, not its own independently-derived platform_id" do
      platform = create(:better_together_platform, :public, host: false)
      community = create(:better_together_community, platform: platform)
      invitation = create(:better_together_community_invitation, invitable: community)

      expect(includer.send(:resolve_invitation_platform, invitation)).to eq(platform)
    end

    it "returns an event invitation's own platform" do
      platform = create(:better_together_platform, :public, host: false)
      event = create(:better_together_event, platform: platform)
      invitation = create(:better_together_event_invitation, invitable: event)

      expect(includer.send(:resolve_invitation_platform, invitation)).to eq(platform)
    end

    it 'returns the invitable itself for a platform invitation' do
      platform = create(:better_together_platform, :public, host: false)
      invitation = create(:better_together_platform_invitation, invitable: platform)

      expect(includer.send(:resolve_invitation_platform, invitation)).to eq(platform)
    end
  end

  describe '#grant_inviter_messaging_permission' do
    it 'creates a messaging grant scoped to the platform invitation was accepted on' do
      platform = create(:better_together_platform, :public, host: false)
      invitation = create(:better_together_platform_invitation, invitable: platform)
      inviter = invitation.inviter
      user = create(:better_together_user, :confirmed)

      includer.send(:grant_inviter_messaging_permission, user, invitation)

      grant = BetterTogether::PersonMessagingGrant.find_by(grantor: user.person, grantee: inviter)
      expect(grant).to be_present
      expect(grant.platform_id).to eq(platform.id)
    end
  end
end
