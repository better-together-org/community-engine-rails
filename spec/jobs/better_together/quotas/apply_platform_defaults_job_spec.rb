# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Quotas::ApplyPlatformDefaultsJob do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  let(:platform) { create(:better_together_platform) }
  let(:person) { create(:better_together_person, platform:) }
  let(:other_person) { create(:better_together_person) }

  def quota_for(owner)
    BetterTogether::Quota.find_or_create_by!(owner:, quota_type: 'media_storage') do |q|
      q.limit = 1
      q.period = 'cumulative'
    end
  end

  it "updates existing quotas on that platform to the platform's override" do
    quota = quota_for(person)
    platform.update!(quota_default_limits: { 'media_storage' => { 'person' => '777' } })

    described_class.perform_now(platform.id)

    expect(quota.reload.limit).to eq(777)
  end

  it 'falls back to YAML for kinds with no override' do
    quota = quota_for(create(:better_together_community, platform:))

    described_class.perform_now(platform.id)

    expect(quota.reload.limit).to eq(1_000_000_000)
  end

  it 'does not touch quotas owned by other platforms' do
    quota = quota_for(other_person)
    platform.update!(quota_default_limits: { 'media_storage' => { 'person' => '777' } })

    described_class.perform_now(platform.id)

    expect(quota.reload.limit).to eq(1)
  end

  it 'leaves quota grants alone' do
    quota_for(person)
    grant = BetterTogether::QuotaGrant.create!(owner: person, quota_type: 'media_storage', limit: 5_000)

    described_class.perform_now(platform.id)

    expect(grant.reload.limit).to eq(5_000)
  end

  it 'does nothing for an external platform' do
    external = create(:better_together_platform, :external)

    expect { described_class.perform_now(external.id) }.not_to raise_error
  end
end
