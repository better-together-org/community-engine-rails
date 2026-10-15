# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261015130000_create_better_together_billing_events')

RSpec.describe 'Create Better Together billing events migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { CreateBetterTogetherBillingEvents.new }

  let(:connection) { ActiveRecord::Base.connection }

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

  it 'enforces one row per processor event at the database level' do
    columns = connection.indexes(:better_together_billing_events).find { |i| i.name == 'idx_bt_billing_events_processor_event' }

    expect(columns).to have_attributes(unique: true, columns: %w[processor event_id])
  end

  it 'has no vendor-specific defaults or columns' do
    names = connection.columns(:better_together_billing_events).map(&:name)

    expect(names).to include('processor', 'event_id', 'payload', 'attempt_count')
    expect(names.grep(/stripe/)).to be_empty
    expect(connection.columns(:better_together_billing_events).find { |c| c.name == 'processor' }.default).to be_nil
  end

  it 'drops and recreates cleanly' do
    migration.down
    expect(connection.table_exists?(:better_together_billing_events)).to be false
    migration.up
    expect(connection.table_exists?(:better_together_billing_events)).to be true
  end
end
