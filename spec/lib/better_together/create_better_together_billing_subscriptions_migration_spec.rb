# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261107100000_create_better_together_billing_subscriptions')

RSpec.describe 'Create Better Together billing subscriptions migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { CreateBetterTogetherBillingSubscriptions.new }

  let(:connection) { ActiveRecord::Base.connection }
  let(:terms) { :better_together_billing_subscription_terms }
  let(:periods) { :better_together_billing_subscription_periods }

  around do |example|
    previous = ActiveRecord::Migration.verbose
    migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = previous
  end

  def composite(table) = connection.foreign_keys(table).select { |key| key.column.is_a?(Array) || key.column.to_s.include?(',') }

  it 'is a no-op when the tables already exist' do
    expect { migration.up }.not_to raise_error
  end

  it 'binds both tables to a platform, NOT NULL, with a foreign key' do
    [terms, periods].each do |table|
      expect(connection.columns(table).find { |column| column.name == 'platform_id' }.null).to be(false)
      expect(connection.foreign_keys(table).map(&:to_table)).to include('better_together_platforms')
    end
  end

  it 'ties terms to the Pay subscription and plan, and periods to terms and orders, by composite keys with the platform' do
    expect(composite(terms).map(&:to_table)).to contain_exactly('pay_subscriptions', 'better_together_billing_plans')
    expect(composite(periods).map(&:to_table)).to contain_exactly('better_together_billing_subscription_terms', 'better_together_billing_orders')
  end

  it 'allows one terms row per Pay subscription and one period per subscription and sequence' do
    by_subscription = connection.indexes(terms).find { |item| item.name == 'idx_bt_billing_sub_terms_subscription' }
    by_sequence = connection.indexes(periods).find { |item| item.name == 'idx_bt_billing_sub_periods_sequence' }

    expect(by_subscription).to have_attributes(unique: true, columns: %w[pay_subscription_id])
    expect(by_sequence).to have_attributes(unique: true, columns: %w[subscription_term_id sequence])
  end

  it 'allows an order to invoice one period at most' do
    index = connection.indexes(periods).find { |item| item.name == 'idx_bt_billing_sub_periods_order' }

    expect(index).to have_attributes(unique: true, columns: %w[order_id])
  end

  it 'checks the amounts and the shape of a period in the database' do
    expect(connection.check_constraints(terms).map(&:name)).to contain_exactly('chk_bt_billing_sub_terms_amounts')
    expect(connection.check_constraints(periods).map(&:name)).to contain_exactly('chk_bt_billing_sub_periods_shape')
  end

  it 'holds the price as bigint and a status that defaults to pending' do
    expect(connection.columns(terms).find { |column| column.name == 'unit_amount_cents' }.sql_type).to eq('bigint')
    expect(connection.columns(periods).find { |column| column.name == 'status' }).to have_attributes(default: 'pending', null: false)
  end

  it 'drops and recreates cleanly' do
    migration.down
    expect([terms, periods].none? { |table| connection.table_exists?(table) }).to be(true)
    migration.up
    expect([terms, periods].all? { |table| connection.table_exists?(table) }).to be(true)
  end
end
