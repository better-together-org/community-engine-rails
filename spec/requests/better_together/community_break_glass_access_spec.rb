# frozen_string_literal: true

require 'rails_helper'

# A break-glass grant opens one private community page, read only, and every read leaves an audit row.
RSpec.describe 'Community break-glass access', :no_auth do
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }
  let(:community) { create(:better_together_community, privacy: 'private') }
  let(:grantee_user) { create(:better_together_user, :confirmed) }
  let(:grantee) { grantee_user.person }

  before do
    host_platform.update_columns(privacy: 'public')
    login_as(grantee_user, scope: :user)
  end

  after { Warden.test_reset! }

  def open_community
    get better_together.community_path(community, locale: I18n.default_locale)
    response.status
  end

  def grant(*traits)
    create(:better_together_break_glass_grant, *traits, subject: community, grantee:)
  end

  def accessed_events
    BetterTogether::BreakGlassEvent.where(event_type: 'accessed')
  end

  it 'refuses a private community without a grant and writes no audit row' do
    expect(open_community).not_to eq(200)
    expect(accessed_events).to be_empty
  end

  it 'opens the community under an active grant and records who read it' do
    grant
    expect(open_community).to eq(200)
    expect(accessed_events.pluck(:actor_id)).to eq([grantee.id])
  end

  it 'records one row for each read' do
    grant
    2.times { open_community }
    expect(accessed_events.count).to eq(2)
  end

  %i[pending expired revoked].each do |trait|
    it "refuses a #{trait} grant" do
      grant(trait)
      expect(open_community).not_to eq(200)
      expect(accessed_events).to be_empty
    end
  end

  it 'does not open the community for a different person' do
    create(:better_together_break_glass_grant, subject: community)
    expect(open_community).not_to eq(200)
  end

  it 'does not write an audit row when a member reads their own community' do
    role = BetterTogether::Role.find_default('community_member', platform: host_platform)
    BetterTogether::PersonCommunityMembership.create!(member: grantee, joinable: community, role:, status: 'active')
    grant
    expect(open_community).to eq(200)
    expect(accessed_events).to be_empty
  end

  describe 'what a grant does not open' do
    let(:grant_record) { grant }
    let(:policy) { BetterTogether::CommunityPolicy.new(grantee_user, community) }

    before { grant_record }

    it 'leaves show, download, the member list and update closed' do
      expect([policy.show?, policy.download?, policy.view_members?, policy.update?, policy.destroy?])
        .to all(be(false))
    end

    it 'keeps the community out of the index scope' do
      scope = BetterTogether::CommunityPolicy::Scope.new(grantee_user, BetterTogether::Community).resolve
      expect(scope).not_to include(community)
    end
  end
end
