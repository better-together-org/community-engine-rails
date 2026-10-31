# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261016120000_create_better_together_billing_agreement_requirements')

RSpec.describe 'Create Better Together billing agreement requirements migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { CreateBetterTogetherBillingAgreementRequirements.new }

  let(:connection) { ActiveRecord::Base.connection }
  let(:requirements) { :better_together_billing_agreement_requirements }
  let(:acceptances) { :better_together_billing_order_agreement_acceptances }

  around do |example|
    previous = ActiveRecord::Migration.verbose
    migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = previous
  end

  def columns(table) = connection.columns(table).index_by(&:name)

  it 'is a no-op when the tables already exist' do
    expect { migration.up }.not_to raise_error
  end

  it 'binds both tables to a platform, NOT NULL, with a foreign key' do
    [requirements, acceptances].each do |table|
      expect(columns(table)['platform_id'].null).to be(false)
      expect(connection.foreign_keys(table).map(&:to_table)).to include('better_together_platforms')
    end
  end

  it 'lets a requirement target nothing (the default), and be limited by purpose and method' do
    expect(columns(requirements).slice('target_type', 'target_id', 'purpose', 'payment_method').values.map(&:null)).to all(be(true))
    expect(columns(requirements)['mode']).to have_attributes(null: false, default: 'additional')
  end

  it 'ties each acceptance to its order\'s platform with a composite foreign key' do
    key = connection.foreign_keys(acceptances).find { |foreign_key| foreign_key.to_table == 'better_together_billing_orders' }

    expect(key.column).to match_array(%w[order_id platform_id])
    expect(key.primary_key).to match_array(%w[id platform_id])
  end

  it 'records an agreement once per order, as it read then' do
    expect(connection.indexes(acceptances).find do |index|
      index.name == 'idx_bt_billing_order_acc_unique'
    end).to have_attributes(unique: true, columns: %w[order_id agreement_id])
    expect(columns(acceptances).slice('agreement_identifier', 'agreement_title', 'agreement_content_digest',
                                      'accepted_at').values.map(&:null)).to all(be(false))
  end

  it 'refuses to delete an agreement that is evidence for an order' do
    keys = connection.foreign_keys(acceptances).select { |foreign_key| foreign_key.to_table == 'better_together_agreements' }

    expect(keys).to be_present
    expect(keys.map(&:on_delete)).to all(be_nil)
  end

  it 'drops and recreates cleanly' do
    migration.down
    [requirements, acceptances].each { |table| expect(connection.table_exists?(table)).to be(false) }
    migration.up
    [requirements, acceptances].each { |table| expect(connection.table_exists?(table)).to be(true) }
  end
end
