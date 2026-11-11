# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Quotas::Types::MediaStorage do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  describe '.default_limit' do
    it 'returns the conservative Person default (250 MiB)' do
      person = create(:better_together_person)
      expect(described_class.default_limit(person)).to eq(250 * (1024**2))
    end

    it 'returns the conservative Community default (1 GiB)' do
      community = create(:better_together_community)
      expect(described_class.default_limit(community)).to eq(1024**3)
    end

    it 'returns the Platform default (10 GiB)' do
      platform = create(:better_together_platform)
      expect(described_class.default_limit(platform)).to eq(10 * (1024**3))
    end

    it 'prefers the owning platform override' do
      person = create(:better_together_person)
      person.platform.update!(quota_default_limits: { 'media_storage' => { 'person' => '123' } })

      expect(described_class.default_limit(person)).to eq(123)
    end
  end

  describe 'a freshly lazily-created Quota row' do
    it "stores the current default, since it's only stamped in at creation time" do
      owner = create(:better_together_person)

      BetterTogether::Quotas.settle!(
        type: 'media_storage', owner:, amount: 1, idempotency_key: 'media_storage_spec:fresh'
      )

      quota = BetterTogether::Quota.find_by(owner:, quota_type: 'media_storage')
      expect(quota.limit).to eq(250 * (1024**2))
    end
  end
end
