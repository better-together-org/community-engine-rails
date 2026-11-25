# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261124220000_create_better_together_billing_purchase_requirements')

RSpec.describe 'Create Better Together billing purchase requirements migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { CreateBetterTogetherBillingPurchaseRequirements.new }

  let(:connection) { ActiveRecord::Base.connection }
  let(:table) { :better_together_billing_purchase_requirements }

  around do |example|
    previous = ActiveRecord::Migration.verbose
    migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = previous
  end

  it 'is a no-op when the table is whole' do
    expect { migration.up }.not_to raise_error
  end

  it 'repairs a table that lost an index and its check constraint on an earlier partial run' do
    connection.remove_index table, name: 'idx_bt_billing_purchase_requirements_one_kind'
    connection.remove_check_constraint table, name: 'chk_bt_billing_purchase_requirements_one_target'

    migration.up

    expect(connection.index_name_exists?(table, 'idx_bt_billing_purchase_requirements_one_kind')).to be(true)
    expect(connection.check_constraint_exists?(table, name: 'chk_bt_billing_purchase_requirements_one_target')).to be(true)
  end
end
