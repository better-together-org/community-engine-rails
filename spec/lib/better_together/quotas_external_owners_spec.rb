# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::Quotas external owners' do # rubocop:disable RSpec/DescribeClass
  include AutomaticTestConfiguration

  before { configure_host_platform }

  let(:external_platform) { create(:better_together_platform, :external) }
  let(:external_person) { create(:better_together_person, platform: external_platform) }

  it 'settle! writes nothing for an external owner' do
    result = BetterTogether::Quotas.settle!(type: 'media_storage', owner: external_person, amount: 5,
                                            idempotency_key: 'external_owner_spec:settle')

    expect([result, BetterTogether::Quota.where(owner: external_person).count,
            BetterTogether::QuotaUsage.where(idempotency_key: 'external_owner_spec:settle').count]).to eq([nil, 0, 0])
  end

  it 'reserve! writes nothing for an external owner' do
    result = BetterTogether::Quotas.reserve!(type: 'media_storage', owner: external_person, amount: 5,
                                             idempotency_key: 'external_owner_spec:reserve')

    expect([result, BetterTogether::QuotaReservation.count]).to eq([nil, 0])
  end

  it 'settle! writes nothing for a nil owner' do
    expect(BetterTogether::Quotas.settle!(type: 'media_storage', owner: nil, amount: 5, idempotency_key: 'external_owner_spec:nil'))
      .to be_nil
  end

  it 'Quota rejects an external owner' do
    quota = BetterTogether::Quota.new(owner: external_person, quota_type: 'media_storage', limit: 1, period: 'cumulative')

    expect(quota).not_to be_valid
  end

  it 'QuotaGrant rejects an external owner' do
    grant = BetterTogether::QuotaGrant.new(owner: external_platform, quota_type: 'media_storage', limit: 1)

    expect(grant).not_to be_valid
  end

  describe BetterTogether::Quotas::OwnerResolver do
    it 'resolves an external owner to nil rather than the host platform' do
      expect(described_class.resolve(external_person)).to be_nil
    end

    it 'still resolves a local person to themselves' do
      person = create(:better_together_person)

      expect(described_class.resolve(person)).to eq(person)
    end
  end
end
