# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261108100000_create_better_together_billing_entitlements')

RSpec.describe 'Create Better Together billing entitlements migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { CreateBetterTogetherBillingEntitlements.new }

  let(:connection) { ActiveRecord::Base.connection }
  let(:tables) { %i[better_together_billing_plan_grants better_together_billing_entitlements better_together_billing_entitlement_grants] }

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

  it 'binds every table to a platform, NOT NULL, with a foreign key' do
    tables.each do |table|
      expect(connection.columns(table).find { |column| column.name == 'platform_id' }.null).to be(false)
      expect(connection.foreign_keys(table).map(&:to_table)).to include('better_together_platforms')
    end
  end

  it 'ties each table to its parents by composite keys that include the platform' do
    expect(composite(tables[0]).map(&:to_table)).to contain_exactly('better_together_billing_plans')
    expect(composite(tables[1]).map(&:to_table)).to contain_exactly('better_together_billing_plans', 'pay_subscriptions',
                                                                    'better_together_billing_orders')
    expect(composite(tables[2]).map(&:to_table)).to contain_exactly('better_together_billing_entitlements')
  end

  it 'requires exactly one source for an entitlement, in the database' do
    expect(connection.check_constraints(tables[1]).map(&:name)).to contain_exactly('chk_bt_billing_entitlements_one_source')
  end

  it 'allows one live entitlement per beneficiary and plan, and one entitlement per source' do
    live = connection.indexes(tables[1]).find { |item| item.name == 'idx_bt_billing_entitlements_one_live' }
    names = connection.indexes(tables[1]).map(&:name)

    expect(live).to have_attributes(unique: true, columns: %w[platform_id beneficiary_type beneficiary_id plan_id])
    expect(live.where).to match(/active.*grace/)
    expect(names).to include('idx_bt_billing_entitlements_subscription', 'idx_bt_billing_entitlements_order')
  end

  it 'names an applied grant once per entitlement, and keeps the kind and parameters it was made with' do
    key = connection.indexes(tables[2]).find { |item| item.name == 'idx_bt_billing_ent_grants_key' }
    columns = connection.columns(tables[2]).map(&:name)

    expect(key).to have_attributes(unique: true, columns: %w[entitlement_id grant_key])
    expect(columns).to include('kind', 'parameters', 'owned', 'quota_type', 'amount')
  end

  it 'drops and recreates cleanly' do
    migration.down
    expect(tables.none? { |table| connection.table_exists?(table) }).to be(true)
    migration.up
    expect(tables.all? { |table| connection.table_exists?(table) }).to be(true)
  end
end
