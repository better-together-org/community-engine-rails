# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261110230000_apply_configured_quota_defaults_to_existing_quotas')

RSpec.describe ApplyConfiguredQuotaDefaultsToExistingQuotas do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  def quota_for(owner, type: 'media_storage')
    BetterTogether::Quota.new(owner:, quota_type: type, limit: 1, period: 'cumulative').tap do |q|
      q.save!(validate: false)
    end
  end

  def migrate_up
    ActiveRecord::Migration.suppress_messages { described_class.new.up }
  end

  it 'brings local person, community and platform quotas to the configured defaults' do
    person = quota_for(create(:better_together_person))
    community = quota_for(create(:better_together_community))
    platform = quota_for(create(:better_together_platform))

    migrate_up

    expect([person, community, platform].map { |q| q.reload.limit })
      .to eq([250 * (1024**2), 1024**3, 10 * (1024**3)])
  end

  it 'leaves quotas owned by external owners alone' do
    external = create(:better_together_platform, :external)
    external_person = quota_for(create(:better_together_person, platform: external))
    external_platform = quota_for(external)

    migrate_up

    expect([external_person, external_platform].map { |q| q.reload.limit }).to eq([1, 1])
  end

  it 'does not touch other quota types' do
    tokens = quota_for(create(:better_together_person), type: 'ai_translation_tokens')

    migrate_up

    expect(tokens.reload.limit).to eq(1)
  end

  it 'is idempotent' do
    person = quota_for(create(:better_together_person))

    2.times { migrate_up }

    expect(person.reload.limit).to eq(250 * (1024**2))
  end
end
