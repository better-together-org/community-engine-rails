# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261016110000_create_better_together_billing_orders')

RSpec.describe 'Create Better Together billing orders migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { CreateBetterTogetherBillingOrders.new }

  let(:connection) { ActiveRecord::Base.connection }
  let(:tables) do
    %i[better_together_billing_orders better_together_billing_order_lines better_together_billing_payments better_together_billing_refunds]
  end

  around do |example|
    previous = ActiveRecord::Migration.verbose
    migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = previous
  end

  def columns(table) = connection.columns(table).index_by(&:name)
  def indexes(table) = connection.indexes(table).index_by(&:name)

  it 'is a no-op when the tables already exist' do
    expect { migration.up }.not_to raise_error
  end

  it 'binds every table to a platform, NOT NULL, with a foreign key' do
    tables.each do |table|
      expect(columns(table)['platform_id'].null).to be(false), "#{table}.platform_id should be NOT NULL"
      expect(connection.foreign_keys(table).map(&:to_table)).to include('better_together_platforms')
    end
  end

  it 'ties each child to its parent\'s platform with a composite foreign key' do
    {
      better_together_billing_order_lines: 'better_together_billing_orders',
      better_together_billing_payments: 'better_together_billing_orders',
      better_together_billing_refunds: 'better_together_billing_payments'
    }.each do |table, parent|
      key = connection.foreign_keys(table).find { |foreign_key| foreign_key.to_table == parent }

      expect(key.column).to match_array(%w[platform_id].push(table.to_s.end_with?('refunds') ? 'payment_id' : 'order_id'))
      expect(key.primary_key).to match_array(%w[id platform_id])
    end
  end

  it 'has the unique (id, platform_id) indexes those keys point at' do
    expect(indexes(:better_together_billing_orders)['idx_bt_billing_orders_id_platform']).to have_attributes(unique: true,
                                                                                                             columns: %w[
                                                                                                               id platform_id
                                                                                                             ])
    expect(indexes(:better_together_billing_payments)['idx_bt_billing_payments_id_platform']).to have_attributes(unique: true,
                                                                                                                 columns: %w[
                                                                                                                   id platform_id
                                                                                                                 ])
  end

  it 'numbers orders per platform, and makes request keys unique per platform' do
    expect(indexes(:better_together_billing_orders)['idx_bt_billing_orders_number']).to have_attributes(unique: true,
                                                                                                        columns: %w[
                                                                                                          platform_id number
                                                                                                        ])
    expect(indexes(:better_together_billing_payments)['idx_bt_billing_payments_idempotency'])
      .to have_attributes(unique: true, columns: %w[platform_id idempotency_key])
    expect(indexes(:better_together_billing_refunds)['idx_bt_billing_refunds_idempotency'])
      .to have_attributes(unique: true, columns: %w[platform_id idempotency_key])
  end

  it 'keeps money as whole minor units with a currency and no default currency' do
    expect(columns(:better_together_billing_orders)['total_cents']).to have_attributes(type: :integer, null: false)
    expect(columns(:better_together_billing_orders)['currency'].default).to be_nil
    expect(columns(:better_together_billing_payments)['amount_cents'].type).to eq(:integer)
    expect(columns(:better_together_billing_refunds)['amount_cents'].type).to eq(:integer)
  end

  it 'starts an order as a draft and a payment as pending' do
    expect(columns(:better_together_billing_orders)['status'].default).to eq('draft')
    expect(columns(:better_together_billing_payments)['status'].default).to eq('pending')
  end

  it 'lets a refund outlive the person who recorded it' do
    key = connection.foreign_keys(:better_together_billing_refunds).find { |foreign_key| foreign_key.column == 'recorded_by_id' }

    expect(key.on_delete).to eq(:nullify)
  end

  it 'drops and recreates cleanly' do
    migration.down
    tables.each { |table| expect(connection.table_exists?(table)).to be(false) }
    migration.up
    tables.each { |table| expect(connection.table_exists?(table)).to be(true) }
  end
end
