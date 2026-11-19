# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261105100000_create_better_together_billing_credit')

RSpec.describe 'Create Better Together billing credit migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { CreateBetterTogetherBillingCredit.new }

  let(:connection) { ActiveRecord::Base.connection }
  let(:tables) { %i[better_together_billing_credit_accounts better_together_billing_credit_lots better_together_billing_credit_entries] }

  around do |example|
    previous = ActiveRecord::Migration.verbose
    migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = previous
  end

  def composite_keys(table) = connection.foreign_keys(table).select { |key| key.column.is_a?(Array) || key.column.to_s.include?(',') }

  it 'is a no-op when the tables already exist' do
    expect { migration.up }.not_to raise_error
  end

  it 'binds every table to a platform, NOT NULL, with a foreign key' do
    tables.each do |table|
      expect(connection.columns(table).find { |column| column.name == 'platform_id' }.null).to be(false)
      expect(connection.foreign_keys(table).map(&:to_table)).to include('better_together_platforms')
    end
  end

  it 'ties lots and entries to their account, lot and reversed entry by composite keys that include the platform' do
    expect(composite_keys(:better_together_billing_credit_lots).map(&:to_table)).to contain_exactly('better_together_billing_credit_accounts')
    expect(composite_keys(:better_together_billing_credit_entries).map(&:to_table))
      .to contain_exactly('better_together_billing_credit_accounts', 'better_together_billing_credit_lots',
                          'better_together_billing_credit_entries')
  end

  it 'makes an account unique per platform, holder and currency, and keeps the ledger when a person is deleted' do
    index = connection.indexes(tables.first).find { |item| item.name == 'idx_bt_billing_credit_accounts_holder_currency' }
    holder_key = connection.foreign_keys(tables.first).find { |key| key.to_table == 'better_together_people' }

    expect(index).to have_attributes(unique: true, columns: %w[platform_id holder_id currency])
    expect(holder_key.on_delete).to eq(:nullify)
  end

  it 'holds money as bigint and checks the balance, the lot bounds and a non-zero entry in the database' do
    money = tables.flat_map { |table| connection.columns(table).select { |column| column.name.end_with?('_cents') } }

    expect(money.map(&:sql_type).uniq).to eq(['bigint'])
    checks = tables.flat_map { |table| connection.check_constraints(table).map(&:name) }
    expect(checks).to contain_exactly('chk_bt_billing_credit_accounts_balance', 'chk_bt_billing_credit_lots_bounds',
                                      'chk_bt_billing_credit_entries_amount')
  end

  it 'makes one entry per operation and lot' do
    index = connection.indexes(:better_together_billing_credit_entries).find { |item| item.name == 'idx_bt_billing_credit_entries_transaction' }

    expect(index).to have_attributes(unique: true, columns: %w[platform_id transaction_key credit_lot_id])
  end

  it 'drops and recreates cleanly' do
    migration.down
    expect(tables.none? { |table| connection.table_exists?(table) }).to be(true)
    migration.up
    expect(tables.all? { |table| connection.table_exists?(table) }).to be(true)
  end
end
