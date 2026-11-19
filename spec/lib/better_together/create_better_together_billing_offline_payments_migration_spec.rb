# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261016140000_create_better_together_billing_offline_payments')

RSpec.describe 'Create Better Together billing offline payments migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { CreateBetterTogetherBillingOfflinePayments.new }

  let(:connection) { ActiveRecord::Base.connection }
  let(:table) { :better_together_billing_offline_payments }
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

  it 'binds every record to a platform, NOT NULL, with a foreign key' do
    expect(columns['platform_id'].null).to be(false)
    expect(connection.foreign_keys(table).map(&:to_table)).to include('better_together_platforms')
  end

  it 'ties each record to its order and payment by composite foreign keys that include the platform' do
    composite = connection.foreign_keys(table).select { |key| key.column.is_a?(Array) || key.column.to_s.include?(',') }

    expect(composite.map(&:to_table)).to contain_exactly('better_together_billing_orders', 'better_together_billing_payments')
    expect(composite.map(&:column).flatten.uniq).to include('platform_id', 'order_id', 'payment_id')
  end

  it 'allows one offline payment per payment' do
    index = connection.indexes(table).find { |item| item.name == 'idx_bt_billing_offline_payments_payment' }

    expect(index).to have_attributes(unique: true, columns: %w[payment_id])
  end

  it 'stores references and instructions as plain text columns with no default, ready for encryption' do
    %w[buyer_reference seller_reference instructions_snapshot].each do |name|
      expect(columns.fetch(name)).to have_attributes(type: :text, default: nil, limit: nil)
    end
  end

  it 'never has a fee but zero, a status, and when the seller must be told' do
    expect(columns['platform_fee_cents']).to have_attributes(default: '0', null: false)
    expect(columns['status']).to have_attributes(default: 'awaiting', null: false)
  end

  it 'drops and recreates cleanly' do
    migration.down
    expect(connection.table_exists?(table)).to be(false)
    migration.up
    expect(connection.table_exists?(table)).to be(true)
  end
end
