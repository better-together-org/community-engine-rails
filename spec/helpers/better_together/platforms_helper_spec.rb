# frozen_string_literal: true

require 'rails_helper'

# Specs in this file have access to a helper object that includes
# the PlatformsHelper. For example:
#
# describe PlatformsHelper do
#   describe "string concat" do
#     it "concats two strings with spaces" do
#       expect(helper.concat_strings("this","that")).to eq("this that")
#     end
#   end
# end
module BetterTogether
  RSpec.describe PlatformsHelper do
    include ActiveSupport::Testing::TimeHelpers

    it 'exists' do
      expect(described_class).to be # rubocop:todo RSpec/Be
    end

    describe '#invitation_token_expires_at' do
      it 'returns nil when no expiry is set in session' do
        expect(helper.invitation_token_expires_at).to be_nil
      end

      it 'returns Unix timestamp in seconds when platform invitation expiry is set as Time object' do
        future_time = 30.minutes.from_now
        helper.session[:platform_invitation_expires_at] = future_time

        result = helper.invitation_token_expires_at

        expect(result).to be_a(Integer)
        expect(result).to eq(future_time.to_i)
        expect(result).to be > Time.current.to_i
      end

      it 'returns Unix timestamp for community invitation expiry' do
        future_time = 30.minutes.from_now
        helper.session[:community_invitation_expires_at] = future_time

        result = helper.invitation_token_expires_at

        expect(result).to be_a(Integer)
        expect(result).to eq(future_time.to_i)
      end

      it 'returns Unix timestamp for event invitation expiry' do
        future_time = 30.minutes.from_now
        helper.session[:event_invitation_expires_at] = future_time

        result = helper.invitation_token_expires_at

        expect(result).to be_a(Integer)
        expect(result).to eq(future_time.to_i)
      end

      it 'returns Unix timestamp in seconds when expiry is set as string' do
        future_time = 30.minutes.from_now
        helper.session[:platform_invitation_expires_at] = future_time.to_s

        result = helper.invitation_token_expires_at

        expect(result).to be_a(Integer)
        expect(result).to be_within(2).of(future_time.to_i) # Allow 2 second tolerance for parsing
      end

      it 'prioritizes platform invitation when multiple invitations are present' do
        platform_time = 30.minutes.from_now
        community_time = 60.minutes.from_now
        helper.session[:platform_invitation_expires_at] = platform_time
        helper.session[:community_invitation_expires_at] = community_time

        result = helper.invitation_token_expires_at

        expect(result).to eq(platform_time.to_i)
      end

      it 'returns a timestamp that indicates remaining time correctly' do
        freeze_time do
          future_time = 30.minutes.from_now
          helper.session[:platform_invitation_expires_at] = future_time

          expires_at = helper.invitation_token_expires_at
          now = Time.current.to_i
          remaining_seconds = expires_at - now

          expect(remaining_seconds).to be_within(5).of(30 * 60) # ~30 minutes in seconds
        end
      end
    end

    describe '#active_invitation_token' do
      it 'returns nil when no invitation token is in session' do
        expect(helper.active_invitation_token).to be_nil
      end

      it 'returns platform invitation token when present' do
        helper.session[:platform_invitation_token] = 'platform_token_123'

        expect(helper.active_invitation_token).to eq('platform_token_123')
      end

      it 'returns community invitation token when present' do
        helper.session[:community_invitation_token] = 'community_token_456'

        expect(helper.active_invitation_token).to eq('community_token_456')
      end

      it 'returns event invitation token when present' do
        helper.session[:event_invitation_token] = 'event_token_789'

        expect(helper.active_invitation_token).to eq('event_token_789')
      end

      it 'prioritizes platform invitation when multiple invitations are present' do
        helper.session[:platform_invitation_token] = 'platform_token'
        helper.session[:community_invitation_token] = 'community_token'

        expect(helper.active_invitation_token).to eq('platform_token')
      end
    end
  end
end
