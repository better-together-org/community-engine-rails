# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::BreakGlass workflow' do # rubocop:disable RSpec/DescribeClass
  let(:community) { create(:better_together_community, privacy: 'private') }
  let(:officer) { create(:better_together_person) }
  let(:steward) { create(:better_together_person) }
  let(:reason) { 'Safety case 42 needs the private community content reviewed.' }

  before do
    role = BetterTogether::Role.find_default('platform_disclosure_officer', platform: community.platform)
    BetterTogether::PersonPlatformMembership.create!(joinable: community.platform, member: officer, role:,
                                                     status: 'active')
    steward_role = BetterTogether::Role.find_default('platform_steward', platform: community.platform)
    BetterTogether::PersonPlatformMembership.create!(joinable: community.platform, member: steward,
                                                     role: steward_role, status: 'active')
  end

  def request(requester: officer, **)
    BetterTogether::BreakGlass::Request.call(requester:, subject: community, reason:, **)
  end

  describe BetterTogether::BreakGlass::Request do
    it 'opens a grant that waits out the delay' do
      grant = request

      expect(grant.state).to eq(:pending)
      expect(grant.available_at).to be_within(1.minute).of(24.hours.from_now)
    end

    it 'writes a requested audit row' do
      grant = request

      expect(grant.events.map(&:event_type)).to eq(['requested'])
      expect(grant.events.first.actor).to eq(officer)
    end

    it 'makes an emergency grant usable at once and flags it' do
      grant = request(emergency: true, reason_code: 'imminent_harm')

      expect(grant.active_now?).to be true
      expect(grant.events.first.detail).to include('emergency' => true, 'reason_code' => 'imminent_harm')
    end

    it 'refuses a platform steward, who does not hold the sealed permission' do
      expect { request(requester: steward) }.to raise_error(BetterTogether::BreakGlass::NotAuthorized)
    end

    it 'refuses a person with no role' do
      expect { request(requester: create(:better_together_person)) }
        .to raise_error(BetterTogether::BreakGlass::NotAuthorized)
    end

    it 'leaves no grant behind when refused' do
      expect { request(requester: steward) }.to raise_error(BetterTogether::BreakGlass::NotAuthorized)
      expect(BetterTogether::BreakGlassGrant.count).to eq(0)
    end
  end

  describe BetterTogether::BreakGlass::Revoke do
    let!(:grant) { request }

    it 'ends the grant and writes an audit row' do
      described_class.call(grant:, actor: officer)

      expect(grant.reload.state).to eq(:revoked)
      expect(grant.events.map(&:event_type)).to eq(%w[requested revoked])
    end

    it 'lets a different holder of the sealed permission revoke' do
      other = create(:better_together_person)
      role = BetterTogether::Role.find_default('platform_disclosure_officer', platform: community.platform)
      BetterTogether::PersonPlatformMembership.create!(joinable: community.platform, member: other, role:,
                                                       status: 'active')

      expect(described_class.call(grant:, actor: other).state).to eq(:revoked)
    end

    it 'refuses a steward with no part in the grant' do
      expect { described_class.call(grant:, actor: steward) }.to raise_error(BetterTogether::BreakGlass::NotAuthorized)
    end
  end

  describe BetterTogether::BreakGlass::RecordAccess do
    it 'writes an accessed row naming the action' do
      grant = request(emergency: true, reason_code: 'imminent_harm')
      described_class.call(grant:, actor: officer, action: :show)

      expect(grant.events.order(:created_at).last.detail).to eq('action' => 'show')
    end
  end
end
