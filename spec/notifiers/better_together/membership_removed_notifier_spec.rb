# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe MembershipRemovedNotifier do
    let(:platform) { create(:better_together_platform) }
    let(:member_data) do
      {
        email: 'user@example.com',
        name: 'Test User',
        locale: 'en',
        role_name: 'Community Member',
        joinable_name: 'Test Community'
      }
    end

    subject(:notifier) do
      described_class.new(
        record: platform,
        params: { member_data: member_data }
      )
    end

    it 'includes joinable name and role in the title' do
      expect(notifier.title).to include(member_data[:joinable_name])
      expect(notifier.title).to include(member_data[:role_name])
    end

    it 'includes joinable name and role in the body' do
      expect(notifier.body).to include(member_data[:joinable_name])
      expect(notifier.body).to include(member_data[:role_name])
    end

    it 'builds a message with URL to the joinable' do
      message = notifier.build_message(nil)

      expect(message[:url]).to be_present
      expect(message[:url]).to include(platform.to_param)
    end

    it 'includes member data in email params' do
      email_params = notifier.email_params(nil)

      expect(email_params[:member_data]).to eq(member_data)
      expect(email_params[:recipient][:email]).to eq(member_data[:email])
      expect(email_params[:recipient][:name]).to eq(member_data[:name])
    end
  end
end
