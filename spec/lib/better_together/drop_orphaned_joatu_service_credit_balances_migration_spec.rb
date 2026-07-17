# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20260717130100_drop_orphaned_joatu_service_credit_balances')

RSpec.describe 'Drop orphaned joatu_service_credit_balances migration' do # rubocop:disable RSpec/DescribeClass
  let(:migration) { DropOrphanedJoatuServiceCreditBalances.new }
  let(:connection) { ActiveRecord::Base.connection }

  before do
    migration.down unless connection.table_exists?(:better_together_joatu_service_credit_balances)
  end

  after do
    migration.down unless connection.table_exists?(:better_together_joatu_service_credit_balances)
  end

  it 'drops the orphaned table' do
    expect(connection.table_exists?(:better_together_joatu_service_credit_balances)).to be(true)

    migration.up

    expect(connection.table_exists?(:better_together_joatu_service_credit_balances)).to be(false)
  end

  it 'is idempotent when run twice' do
    migration.up
    expect { migration.up }.not_to raise_error
  end

  it 'can be reversed' do
    migration.up
    migration.down

    expect(connection.table_exists?(:better_together_joatu_service_credit_balances)).to be(true)
  end
end
