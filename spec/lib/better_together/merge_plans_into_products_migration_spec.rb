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
end
