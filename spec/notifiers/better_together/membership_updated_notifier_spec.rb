# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe MembershipUpdatedNotifier do
    let(:old_role) { create(:better_together_role, :community_role, name: 'Community Member') }
    let(:new_role) { create(:better_together_role, :community_role, name: 'Community Moderator') }
    let(:membership) { create(:better_together_person_community_membership, role: new_role) }

    subject(:notifier) do
      described_class.new(
        record: membership,
        params: {
          membership: membership,
          old_role: old_role,
          new_role: new_role
        }
      )
    end

    it 'includes joinable name and roles in the title' do
      expect(notifier.title).to include(membership.joinable.name)
      expect(notifier.title).to include(old_role.name)
      expect(notifier.title).to include(new_role.name)
    end

    it 'includes joinable name and roles in the body' do
      expect(notifier.body).to include(membership.joinable.name)
      expect(notifier.body).to include(old_role.name)
      expect(notifier.body).to include(new_role.name)
    end

    it 'builds a message with a url' do
      message = notifier.build_message(nil)

      expect(message[:url]).to be_present
    end

    it 'includes old and new roles in email params' do
      email_params = notifier.email_params(nil)

      expect(email_params[:old_role]).to eq(old_role)
      expect(email_params[:new_role]).to eq(new_role)
      expect(email_params[:membership]).to eq(membership)
    end
  end
end
