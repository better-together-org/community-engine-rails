# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261015120000_create_better_together_pay_tables')

RSpec.describe 'Create Better Together Pay tables migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { CreateBetterTogetherPayTables.new }

  let(:connection) { ActiveRecord::Base.connection }
  let(:platform_tables) { %i[pay_customers pay_merchants pay_payment_methods pay_subscriptions pay_charges] }

  # Migration.verbose is class-level state, so put it back for the specs that follow.
  around do |example|
    previous = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = previous
  end

  def column(table, name) = connection.columns(table).find { |c| c.name == name.to_s }

  it 'is idempotent when the tables already exist' do
    expect { migration.up }.not_to raise_error
    expect(connection.table_exists?(:pay_customers)).to be true
  end

  it 'uses uuid keys like every other Community Engine table' do
    (platform_tables + [:pay_webhooks]).each do |table|
      expect(column(table, :id).sql_type).to eq('uuid')
    end
    expect(column(:pay_customers, :owner_id).sql_type).to eq('uuid')
  end

  it 'creates the STI and payment method type columns directly, with nothing to backfill' do
    %i[pay_customers pay_charges pay_subscriptions pay_payment_methods pay_merchants].each do |table|
      expect(connection.column_exists?(table, :type)).to be true
    end
    expect(connection.column_exists?(:pay_payment_methods, :payment_method_type)).to be true
    expect(connection.column_exists?(:pay_charges, :object)).to be true
  end

  it 'binds every table that holds tenant data to a platform, NOT NULL, with a foreign key' do
    platform_tables.each do |table|
      expect(column(table, :platform_id).null).to be(false), "#{table}.platform_id must be NOT NULL"
      expect(connection.foreign_keys(table).map(&:to_table)).to include('better_together_platforms')
    end
  end

  it 'leaves the transient pay_webhooks rows without a platform' do
    expect(connection.column_exists?(:pay_webhooks, :platform_id)).to be false
  end

  it 'ties children to their parent platform with composite foreign keys' do
    composite = ->(table, to) { connection.foreign_keys(table).find { |fk| fk.to_table == to && fk.column.is_a?(Array) } }

    expect(composite.call('pay_charges', 'pay_customers').column).to eq(%w[customer_id platform_id])
    expect(composite.call('pay_charges', 'pay_subscriptions').column).to eq(%w[subscription_id platform_id])
    expect(composite.call('pay_subscriptions', 'pay_customers').column).to eq(%w[customer_id platform_id])
    expect(composite.call('pay_payment_methods', 'pay_customers').column).to eq(%w[customer_id platform_id])
  end

  it 'holds the encrypted JSON as text, because ciphertext is not a JSON document' do
    {
      pay_customers: %i[data object], pay_merchants: %i[data], pay_payment_methods: %i[data],
      pay_subscriptions: %i[data object metadata], pay_charges: %i[data object metadata], pay_webhooks: %i[event]
    }.each do |table, names|
      names.each { |name| expect(column(table, name).type).to eq(:text), "#{table}.#{name} must be text" }
    end
  end

  it 'scopes uniqueness to the platform, so two platforms can hold the same owner' do
    index = connection.indexes(:pay_customers).find { |i| i.name == 'pay_customer_owner_index' }

    expect(index.columns).to eq(%w[platform_id owner_type owner_id deleted_at])
    expect(index.unique).to be(true)
  end

  it 'rolls back by dropping the Pay tables, and can be run again' do
    migration.down
    expect(connection.table_exists?(:pay_customers)).to be false
    expect(connection.table_exists?(:pay_webhooks)).to be false

    migration.up
    expect(connection.table_exists?(:pay_customers)).to be true
    expect(connection.foreign_keys(:pay_charges).count { |fk| fk.column.is_a?(Array) }).to eq(2)
  end
end
