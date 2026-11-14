# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261016100000_create_better_together_billing_processor_settings')

RSpec.describe 'Create Better Together billing processor settings migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { CreateBetterTogetherBillingProcessorSettings.new }

  let(:connection) { ActiveRecord::Base.connection }
  let(:table) { :better_together_billing_processor_settings }
  let(:columns) { connection.columns(table).index_by(&:name) }
  let(:indexes) { connection.indexes(table).index_by(&:name) }

  around do |example|
    previous = ActiveRecord::Migration.verbose
    migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = previous
  end

  it 'is a no-op when the table already exists' do
    expect { migration.up }.not_to raise_error
  end

  it 'binds every row to a platform, with a foreign key' do
    expect(columns['platform_id'].null).to be(false)
    expect(connection.foreign_keys(table).map(&:to_table)).to include('better_together_platforms')
  end

  it 'is off by default and holds an unpaid order for three days' do
    expect(columns['enabled']).to have_attributes(null: false, default: 'false')
    expect(columns['hold_hours'].default).to eq('72')
  end

  it 'keeps the settings in a text column the model encrypts: no default and no limit' do
    expect(columns['settings']).to have_attributes(type: :text, null: false, default: nil, limit: nil)
  end

  it 'allows one row per method for the platform itself and one per method for each seller' do
    expect(indexes['idx_bt_billing_proc_settings_platform_method'])
      .to have_attributes(unique: true, columns: %w[platform_id processor], where: a_string_matching(/seller_id IS NULL/))
    expect(indexes['idx_bt_billing_proc_settings_seller_method'])
      .to have_attributes(unique: true, columns: %w[platform_id seller_type seller_id processor],
                          where: a_string_matching(/seller_id IS NOT NULL/))
  end

  it 'records who accepted the drawbacks, without blocking the removal of that person' do
    foreign_key = connection.foreign_keys(table).find { |key| key.column == 'acknowledged_by_id' }

    expect(foreign_key).to have_attributes(to_table: 'better_together_people', on_delete: :nullify)
  end

  it 'has no vendor-specific columns' do
    expect(columns.keys.grep(/stripe|vendor/)).to be_empty
  end

  it 'drops and recreates cleanly' do
    migration.down
    expect(connection.table_exists?(table)).to be(false)
    migration.up
    expect(connection.table_exists?(table)).to be(true)
  end
end
