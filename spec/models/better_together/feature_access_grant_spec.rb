# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FeatureAccessGrant do
  describe 'validations' do
    it 'requires a known feature key' do
      grant = build(:better_together_feature_access_grant, feature_key: 'unknown_feature')

      expect(grant).not_to be_valid
      expect(grant.errors[:feature_key]).to be_present
    end

    it 'rejects duplicate active grants for the same platform, person, and feature' do
      grant = create(:better_together_feature_access_grant)
      duplicate = build(:better_together_feature_access_grant,
                        platform: grant.platform,
                        person: grant.person,
                        feature_key: grant.feature_key)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:person_id]).to include('has already been taken')
    end

    it 'allows a replacement grant when the earlier grant was revoked' do
      grant = create(:better_together_feature_access_grant)
      grant.revoke!

      replacement = build(:better_together_feature_access_grant,
                          platform: grant.platform,
                          person: grant.person,
                          feature_key: grant.feature_key)

      expect(replacement).to be_valid
    end

    it 'allows a replacement grant when the earlier grant has expired' do
      expired_grant = create(:better_together_feature_access_grant, expires_at: 1.day.ago)

      replacement = build(:better_together_feature_access_grant,
                          platform: expired_grant.platform,
                          person: expired_grant.person,
                          feature_key: expired_grant.feature_key)

      expect(replacement).to be_valid
      expect(expired_grant.reload.revoked_at).to be_present
    end
  end

  describe 'lifecycle helpers' do
    it 'treats revoked grants as inactive' do
      grant = create(:better_together_feature_access_grant)

      grant.revoke!

      expect(grant.reload).not_to be_active_now
      expect(described_class.active).not_to include(grant)
    end

    it 'preserves the original revoked_at when revoke! is called again' do
      original_revoked_at = 2.days.ago.change(usec: 0)
      grant = create(:better_together_feature_access_grant, revoked_at: original_revoked_at)

      expect { grant.revoke!(revoked_time: Time.current) }
        .not_to(change { grant.reload.revoked_at })
    end

    it 'treats expired grants as inactive' do
      grant = create(:better_together_feature_access_grant, expires_at: 2.minutes.ago)

      expect(grant).not_to be_active_now
      expect(described_class.active).not_to include(grant)
    end

    it 'marks itself revoked when saved after expiry' do
      grant = build(:better_together_feature_access_grant, expires_at: 5.minutes.ago)

      grant.save!

      expect(grant.revoked_at).to eq(grant.expires_at)
    end
  end
end
