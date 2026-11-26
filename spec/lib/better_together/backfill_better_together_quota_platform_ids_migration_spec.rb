# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261104100000_backfill_better_together_quota_platform_ids')

RSpec.describe 'Backfill quota platform ids migration' do # rubocop:disable RSpec/DescribeClass
  include AutomaticTestConfiguration

  subject(:migration) { BackfillBetterTogetherQuotaPlatformIds.new }

  let!(:host_platform) { configure_host_platform }
  let(:other) { create(:better_together_platform) }
  let(:member) { create(:better_together_person, platform: other) }

  around do |example|
    previous = ActiveRecord::Migration.verbose
    migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = previous
  end

  def wrong_platform!(*records)
    records.each { |record| record.class.where(id: record.id).update_all(platform_id: host_platform.id) } # rubocop:disable Rails/SkipsModelValidations
  end

  it 'gives every row its owner\'s platform, not the one a job happened to fall back to' do
    usage = BetterTogether::Quotas.settle!(type: 'media_storage', owner: member, amount: 5, idempotency_key: 'm:1')
    hold = BetterTogether::Quotas.reserve!(type: 'media_storage', owner: member, amount: 5, idempotency_key: 'm:2')
    quota = usage.quota
    balance = BetterTogether::QuotaBalance.find_by!(quota:)
    wrong_platform!(usage, hold, quota, balance)

    migration.up

    [usage, hold, quota, balance].each { |record| expect(record.class.find(record.id).platform_id).to eq(other.id) }
  end

  it 'gives a platform\'s own rows its own id' do
    usage = BetterTogether::Quotas.settle!(type: 'media_storage', owner: other, amount: 5, idempotency_key: 'm:3')
    wrong_platform!(usage)

    migration.up

    expect(usage.reload.platform_id).to eq(other.id)
  end

  it 'is safe to run again, and leaves rows that are already right alone' do
    usage = BetterTogether::Quotas.settle!(type: 'media_storage', owner: member, amount: 5, idempotency_key: 'm:4')

    expect { 2.times { migration.up } }.not_to(change { usage.reload.platform_id })
  end
end
