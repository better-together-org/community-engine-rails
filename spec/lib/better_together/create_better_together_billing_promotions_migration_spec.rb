# frozen_string_literal: true

require 'rails_helper'
require BetterTogether::Engine.root.join('db/migrate/20261106100000_create_better_together_billing_promotions')

RSpec.describe 'Create Better Together billing promotions migration' do # rubocop:disable RSpec/DescribeClass
  subject(:migration) { CreateBetterTogetherBillingPromotions.new }

  let(:connection) { ActiveRecord::Base.connection }
  let(:promotions) { :better_together_billing_promotions }
  let(:redemptions) { :better_together_billing_promotion_redemptions }

  around do |example|
    previous = ActiveRecord::Migration.verbose
    migration.verbose = false
    example.run
  ensure
    ActiveRecord::Migration.verbose = previous
  end

  it 'is a no-op when the tables already exist' do
    expect { migration.up }.not_to raise_error
  end

  it 'binds both tables to a platform, NOT NULL, with a foreign key' do
    [promotions, redemptions].each do |table|
      expect(connection.columns(table).find { |column| column.name == 'platform_id' }.null).to be(false)
      expect(connection.foreign_keys(table).map(&:to_table)).to include('better_together_platforms')
    end
  end

  it 'stores only a digest, never a code, unique per platform' do
    names = connection.columns(promotions).map(&:name)
    index = connection.indexes(promotions).find { |item| item.name == 'idx_bt_billing_promotions_code' }

    expect(names).to include('code_digest')
    expect(names).not_to include('code', 'code_plain')
    expect(index).to have_attributes(unique: true, columns: %w[platform_id code_digest])
  end

  it 'ties a redemption to its promotion and lot by composite keys that include the platform, once per person' do
    composite = connection.foreign_keys(redemptions).select { |key| key.column.is_a?(Array) || key.column.to_s.include?(',') }
    once = connection.indexes(redemptions).find { |item| item.name == 'idx_bt_billing_promo_redemptions_once' }

    expect(composite.map(&:to_table)).to contain_exactly('better_together_billing_promotions', 'better_together_billing_credit_lots')
    expect(once).to have_attributes(unique: true, columns: %w[promotion_id person_id])
  end

  it 'checks the amount, the days, the cap and the count in the database' do
    expect(connection.check_constraints(promotions).map(&:name))
      .to contain_exactly('chk_bt_billing_promotions_amount', 'chk_bt_billing_promotions_days', 'chk_bt_billing_promotions_cap',
                          'chk_bt_billing_promotions_count')
  end

  it 'drops and recreates cleanly' do
    migration.down
    expect([promotions, redemptions].none? { |table| connection.table_exists?(table) }).to be(true)
    migration.up
    expect([promotions, redemptions].all? { |table| connection.table_exists?(table) }).to be(true)
  end
end
