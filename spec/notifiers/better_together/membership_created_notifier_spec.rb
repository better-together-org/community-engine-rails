# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe MembershipCreatedNotifier do
    let(:role) { create(:better_together_role, :community_role, name: 'Community Member') }
    let(:membership) { create(:better_together_person_community_membership, role: role) }

    subject(:notifier) { described_class.new(record: membership, params: { membership: membership }) }

    it 'includes joinable name and role in the title' do
      expect(notifier.title).to include(membership.joinable.name)
      expect(notifier.title).to include(membership.role.name)
    end

    it 'includes joinable name and role in the body' do
      expect(notifier.body).to include(membership.joinable.name)
      expect(notifier.body).to include(membership.role.name)
    end

    it 'builds a message with a url' do
      message = notifier.build_message(nil)

      expect(message[:url]).to be_present
    end
  end
end
