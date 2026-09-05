# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260412213000_require_invitations_for_existing_communities')

RSpec.describe 'Require invitations for existing communities migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { RequireInvitationsForExistingCommunities.new }

  it "does not override a community's existing allow_membership_requests or requires_invitation values on re-run" do
    open_community = create(:better_together_community, allow_membership_requests: true, requires_invitation: false)
    closed_community = create(:better_together_community, allow_membership_requests: false, requires_invitation: true)

    migration.up

    expect(open_community.reload.allow_membership_requests).to be(true)
    expect(open_community.requires_invitation).to be(false)
    expect(closed_community.reload.allow_membership_requests).to be(false)
    expect(closed_community.requires_invitation).to be(true)
  end
end
