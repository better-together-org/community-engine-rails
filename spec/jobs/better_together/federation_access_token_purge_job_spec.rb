# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederationAccessTokenPurgeJob do
  include ActiveJob::TestHelper

  describe 'queueing' do
    it 'uses the maintenance queue' do
      expect(described_class.new.queue_name).to eq('maintenance')
    end
  end

  describe '#perform' do
    let!(:active_token) do
      create(:better_together_federation_access_token, expires_at: 10.minutes.from_now)
    end

    let!(:recently_expired_token) do
      create(:better_together_federation_access_token, expires_at: 30.minutes.ago)
    end

    let!(:stale_expired_token) do
      create(:better_together_federation_access_token, expires_at: 2.hours.ago)
    end

    let!(:stale_revoked_token) do
      create(:better_together_federation_access_token,
             expires_at: 10.minutes.from_now,
             revoked_at: 2.hours.ago)
    end

    it 'deletes tokens expired more than 1 hour ago' do
      expect { described_class.perform_now }
        .to change(BetterTogether::FederationAccessToken, :count).by(-2) # stale_expired + stale_revoked
    end

    it 'preserves active tokens' do
      described_class.perform_now
      expect(BetterTogether::FederationAccessToken.exists?(active_token.id)).to be true
    end

    it 'preserves recently expired tokens within grace period' do
      described_class.perform_now
      expect(BetterTogether::FederationAccessToken.exists?(recently_expired_token.id)).to be true
    end
  end
end
