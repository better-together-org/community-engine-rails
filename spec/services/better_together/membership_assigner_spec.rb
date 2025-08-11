# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe MembershipAssigner, type: :service do
    subject(:assigner) do
      described_class.call(person:, host_platform:, host_community:)
    end

    let(:person) { create(:better_together_person) }
    let(:host_platform) { create(:better_together_platform, :host) }
    let(:host_community) { host_platform.community }
    let!(:platform_role) do
      create(:better_together_role,
             identifier: 'platform_manager',
             resource_type: 'BetterTogether::Platform')
    end
    let!(:community_role) do
      create(:better_together_role,
             identifier: 'community_governance_council',
             resource_type: 'BetterTogether::Community')
    end

    describe '.call' do
      it 'creates memberships and assigns community creator' do
        assigner

        expect(host_platform.person_platform_memberships.where(member: person, role: platform_role)).to exist
        expect(host_community.person_community_memberships.where(member: person, role: community_role)).to exist
        expect(host_community.reload.creator).to eq(person)
      end

      it 'rolls back all changes if a step fails' do
        allow(host_community).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(host_community))

        expect { assigner }.to raise_error(ActiveRecord::RecordInvalid)

        expect(host_platform.person_platform_memberships.where(member: person)).not_to exist
        expect(host_community.person_community_memberships.where(member: person)).not_to exist
        expect(host_community.reload.creator).to be_nil
      end
    end
  end
end
