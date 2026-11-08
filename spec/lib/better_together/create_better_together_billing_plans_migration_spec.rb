# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261015140000_create_better_together_billing_plans')

RSpec.describe 'Create Better Together billing plans migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { CreateBetterTogetherBillingPlans.new }

  let(:connection) { ActiveRecord::Base.connection }
  let(:columns) { connection.columns(:better_together_billing_plans).index_by(&:name) }

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

  it 'uses processor-neutral columns and no currency default' do
    expect(columns.keys).to include('processor', 'processor_price_id', 'processor_product_id', 'synced_to_processor_at')
    expect(columns.keys.grep(/stripe/)).to be_empty
    expect(columns['currency'].default).to be_nil
    expect(columns['currency'].null).to be false
  end

  it 'makes a price unique per processor and leaves a product shareable between prices' do
    indexes = connection.indexes(:better_together_billing_plans).index_by(&:name)

    expect(indexes['idx_bt_billing_plans_processor_price']).to have_attributes(unique: true, columns: %w[processor processor_price_id])
    expect(indexes['idx_bt_billing_plans_processor_product']).to have_attributes(unique: false, columns: %w[processor processor_product_id])
  end

  it 'requires a platform, with a foreign key' do
    expect(columns['platform_id'].null).to be false
    expect(connection.foreign_keys(:better_together_billing_plans).map(&:to_table)).to include('better_together_platforms')
  end

  it 'makes the identifier unique per seller: one index for the platform itself, one for each other seller' do
    indexes = connection.indexes(:better_together_billing_plans).index_by(&:name)

    expect(indexes['idx_bt_billing_plans_platform_identifier'])
      .to have_attributes(unique: true, columns: %w[platform_id identifier], where: a_string_matching(/seller_id IS NULL/))
    expect(indexes['idx_bt_billing_plans_seller_identifier'])
      .to have_attributes(unique: true, columns: %w[platform_id seller_type seller_id identifier],
                          where: a_string_matching(/seller_id IS NOT NULL/))
  end

  it 'lets a plan have no online processor and lists the other ways to pay' do
    expect(columns['processor'].null).to be true
    expect(columns['accepted_payment_methods']).to have_attributes(null: false, array: true)
    expect(columns['accepted_payment_methods'].default).to eq('{}')
    expect(columns.keys).to include('seller_type', 'seller_id')
  end

  it 'lets the price be empty until the processor has created it, and tracks the sync' do
    expect(columns['processor_price_id'].null).to be true
    expect(columns['sync_status']).to have_attributes(null: false, default: 'pending')
    expect(columns.keys).to include('sync_error', 'sync_attempted_at', 'manages_processor_product')
  end

  it 'drops and recreates cleanly' do
    migration.down
    expect(connection.table_exists?(:better_together_billing_plans)).to be false
    migration.up
    expect(connection.table_exists?(:better_together_billing_plans)).to be true
  end
end
