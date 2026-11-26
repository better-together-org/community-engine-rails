# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261016130000_create_better_together_billing_notification_receipts')

RSpec.describe 'Create Better Together billing notification receipts migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { CreateBetterTogetherBillingNotificationReceipts.new }

  let(:connection) { ActiveRecord::Base.connection }
  let(:table) { :better_together_billing_notification_receipts }
  let(:columns) { connection.columns(table).index_by(&:name) }

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

  it 'binds every receipt to a platform, NOT NULL, with a foreign key' do
    expect(columns['platform_id'].null).to be(false)
    expect(connection.foreign_keys(table).map(&:to_table)).to include('better_together_platforms')
  end

  it 'stores only who, what kind and about what, nothing personal' do
    expect(columns.keys).to include('recipient_id', 'kind', 'audience', 'dedupe_key')
    expect(columns.keys.grep(/email|name|body|title|payload/)).to be_empty
  end

  it 'makes a person\'s notice of one thing unique, and goes with the person' do
    index = connection.indexes(table).find { |item| item.name == 'idx_bt_billing_notif_receipts_unique' }
    key = connection.foreign_keys(table).find { |foreign_key| foreign_key.column == 'recipient_id' }

    expect(index).to have_attributes(unique: true, columns: %w[platform_id recipient_id kind dedupe_key])
    expect(key.on_delete).to eq(:cascade)
  end

  it 'drops and recreates cleanly' do
    migration.down
    expect(connection.table_exists?(table)).to be(false)
    migration.up
    expect(connection.table_exists?(table)).to be(true)
  end
end
