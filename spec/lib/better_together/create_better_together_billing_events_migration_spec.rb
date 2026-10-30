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

  it 'records what an event is about and what it meant, in processor-neutral terms' do
    names = connection.columns(:better_together_billing_events).map(&:name)
    indexes = connection.indexes(:better_together_billing_events).map(&:name)

    expect(names).to include('subject_type', 'subject_id', 'outcome_kind')
    expect(indexes).to include('idx_bt_billing_events_subject', 'idx_bt_billing_events_outcome_kind')
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

  it 'binds every event to a platform, NOT NULL, with a foreign key' do
    column = connection.columns(:better_together_billing_events).find { |c| c.name == 'platform_id' }

    expect(column.null).to be(false)
    expect(connection.foreign_keys(:better_together_billing_events).map(&:to_table)).to include('better_together_platforms')
  end

  it 'holds the encrypted payload and error text as text columns with no default' do
    %w[payload error_message].each do |name|
      column = connection.columns(:better_together_billing_events).find { |c| c.name == name }

      expect(column.type).to eq(:text)
      expect(column.default).to be_nil
    end
  end

  it 'records when the processor says an event happened and a lease for the job holding it' do
    expect(connection.column_exists?(:better_together_billing_events, :processor_event_created_at, :datetime)).to be true
    expect(connection.column_exists?(:better_together_billing_events, :claimed_at, :datetime)).to be true
  end

  it 'drops and recreates cleanly' do
    migration.down
    expect(connection.table_exists?(:better_together_billing_events)).to be false
    migration.up
    expect(connection.table_exists?(:better_together_billing_events)).to be true
  end
end
