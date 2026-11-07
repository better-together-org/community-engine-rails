# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Quotas::Types::MediaStorage do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  describe '.default_limit' do
    it 'returns the real-data-informed Person default' do
      person = create(:better_together_person)
      expect(described_class.default_limit(person)).to eq(described_class::PERSON_DEFAULT_BYTES)
      expect(described_class::PERSON_DEFAULT_BYTES).to eq(2 * (1024**3))
    end

    it 'returns the real-data-informed Community default' do
      community = create(:better_together_community)
      expect(described_class.default_limit(community)).to eq(described_class::COMMUNITY_DEFAULT_BYTES)
      expect(described_class::COMMUNITY_DEFAULT_BYTES).to eq(10 * (1024**3))
    end

    it 'returns the finite Platform ceiling for any other owner kind' do
      platform = create(:better_together_platform)
      expect(described_class.default_limit(platform)).to eq(described_class::PLATFORM_DEFAULT_BYTES)
      expect(described_class::PLATFORM_DEFAULT_BYTES).to eq(1024 * (1024**3))
    end
  end

  describe 'a freshly lazily-created Quota row' do
    it "stores the current default, since it's only stamped in at creation time" do
      owner = create(:better_together_person)

      BetterTogether::Quotas.settle!(
        type: 'media_storage', owner:, amount: 1, idempotency_key: 'media_storage_spec:fresh'
      )

      quota = BetterTogether::Quota.find_by(owner:, quota_type: 'media_storage')
      expect(quota.limit).to eq(described_class::PERSON_DEFAULT_BYTES)
    end
  end
end
