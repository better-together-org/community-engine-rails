# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261015120000_create_better_together_pay_tables')

RSpec.describe 'Create Better Together Pay tables migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { CreateBetterTogetherPayTables.new }

  let(:connection) { ActiveRecord::Base.connection }

  around do |example|
    previous = ActiveRecord::Migration.verbose
    migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = previous
  end

  it 'is idempotent on a schema that already has the tables' do
    expect { migration.up }.not_to raise_error
    expect(connection.table_exists?(:pay_customers)).to be true
  end

  it 'uses uuid keys and carries the STI and object columns' do
    expect(connection.columns(:pay_customers).find { |c| c.name == 'id' }.sql_type).to eq('uuid')
    expect(connection.column_exists?(:pay_subscriptions, :type)).to be true
    expect(connection.column_exists?(:pay_charges, :object)).to be true
    expect(connection.column_exists?(:pay_payment_methods, :payment_method_type)).to be true
  end

  it 'adds missing columns to a table from an older Pay install and backfills STI types' do
    connection.remove_column :pay_customers, :type
    connection.execute(<<~SQL.squish)
      INSERT INTO pay_customers (id, processor, processor_id, created_at, updated_at)
      VALUES (gen_random_uuid(), 'stripe', 'cus_old', now(), now())
    SQL

    migration.up

    expect(connection.select_value("SELECT type FROM pay_customers WHERE processor_id = 'cus_old'")).to eq('Pay::Stripe::Customer')
  end

  it 'rolls back by dropping only Pay tables' do
    migration.down
    expect(connection.table_exists?(:pay_customers)).to be false
    migration.up
    expect(connection.table_exists?(:pay_customers)).to be true
  end
end
