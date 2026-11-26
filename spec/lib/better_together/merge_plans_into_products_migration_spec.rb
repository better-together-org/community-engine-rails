# frozen_string_literal: true

require 'rails_helper'
require Rails.root.join('../../db/migrate/20261126040000_merge_plans_into_products.rb').to_s

RSpec.describe 'Merge plans into products migration' do # rubocop:disable RSpec/DescribeClass
  let(:connection) { ActiveRecord::Base.connection }

  it 'leaves no plans table, and plans live in products' do
    expect(connection.table_exists?(:better_together_billing_plans)).to be(false)
    expect(connection.columns(:better_together_billing_products).map(&:name))
      .to include('grace_days', 'renewal_lead_days', 'manages_processor_product', 'accepted_payment_methods')
  end

  it 'points terms at a price and entitlements and grants at a product' do
    expect(connection.columns(:better_together_billing_subscription_terms).map(&:name)).to include('price_id')
    expect(connection.columns(:better_together_billing_entitlements).map(&:name)).to include('product_id')
    expect(connection.columns(:better_together_billing_grants).map(&:name)).to include('product_id')
  end

  # A plan and a product could share an identifier while they lived in separate tables, and the products table makes it unique.
  describe 'a plan whose identifier a product already uses' do
    let!(:host_platform) { configure_host_platform }
    let(:identifiers) do
      connection.create_table(:better_together_billing_plans, id: :uuid) do |t|
        t.uuid :platform_id
        t.string :seller_type
        t.uuid :seller_id
        t.string :identifier
      end
      create(:better_together_billing_product, platform: host_platform, identifier: 'supporter')
      taken = SecureRandom.uuid
      free = SecureRandom.uuid
      [taken, free].zip(%w[supporter free]).each do |id, identifier|
        connection.execute(
          "INSERT INTO better_together_billing_plans (id, platform_id, identifier) VALUES ('#{id}', '#{host_platform.id}', '#{identifier}')"
        )
      end
      sql = "SELECT plan.id, #{MergePlansIntoProducts.new.send(:plan_identifier)} AS identifier FROM better_together_billing_plans plan"
      connection.select_rows(sql).to_h.transform_keys { |id| id == taken ? :taken : :free }
    end

    it 'keeps a free identifier and suffixes a taken one, so the copy cannot violate the unique index' do
      expect(identifiers[:free]).to eq('free')
      expect(identifiers[:taken]).to match(/\Asupporter-plan-[0-9a-f]{8}\z/)
    end
  end

  # An add-on or one-time plan from before plans were only recurring: it must not block the upgrade, and it keeps its id.
  describe 'a plan that was sold once' do
    let!(:host_platform) { configure_host_platform }
    let(:plan_ids) { { once: SecureRandom.uuid, monthly: SecureRandom.uuid } }

    before do
      connection.create_table(:better_together_billing_plans, id: :uuid) do |t|
        t.integer :lock_version, default: 0
        t.timestamps null: false, default: -> { 'now()' }
        t.uuid :platform_id
        t.string :seller_type
        t.uuid :seller_id
        t.string :identifier
        t.boolean :active, default: true
        t.boolean :listed, default: false
        t.boolean :restricted_to_members, default: false
        t.boolean :restricted_to_subscribers, default: false
        t.uuid :tax_category_id
        t.string :processor
        t.string :processor_product_id
        t.jsonb :metadata, default: {}
        t.string :sync_status, default: 'synced'
        t.string :sync_error
        t.datetime :sync_attempted_at
        t.datetime :synced_to_processor_at
        t.integer :grace_days, default: 7
        t.integer :renewal_lead_days, default: 14
        t.boolean :manages_processor_product, default: true
        t.string :accepted_payment_methods, array: true, default: []
        t.string :latest_processor_event_id
        t.integer :amount_cents
        t.string :currency
        t.string :processor_price_id
        t.string :billing_interval
        t.integer :interval_count, default: 1
      end
      { once: ['topup', 'one_time', 500], monthly: ['member', 'month', 1000] }.each do |key, (identifier, interval, cents)|
        connection.execute(<<~SQL.squish)
          INSERT INTO better_together_billing_plans (id, platform_id, identifier, billing_interval, amount_cents, currency)
          VALUES ('#{plan_ids[key]}', '#{host_platform.id}', '#{identifier}', '#{interval}', #{cents}, 'CAD')
        SQL
      end
      migration = MergePlansIntoProducts.new
      migration.instance_variable_set(:@connection, connection)
      migration.suppress_messages { migration.send(:copy_plans) }
    end

    it 'becomes a plain product with a one-time price, and a recurring plan stays a plan with a recurring price' do
      types = connection.select_rows('SELECT id::text, type FROM better_together_billing_products').to_h
      kinds = connection.select_rows('SELECT product_id::text, kind FROM better_together_billing_prices').to_h

      expect(types.values_at(plan_ids[:once], plan_ids[:monthly])).to eq(%w[BetterTogether::Billing::Product BetterTogether::Billing::Plan])
      expect(kinds.values_at(plan_ids[:once], plan_ids[:monthly])).to eq(%w[one_time recurring])
    end
  end
end
