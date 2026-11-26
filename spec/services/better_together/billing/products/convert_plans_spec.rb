# frozen_string_literal: true

require 'rails_helper'

# PS-6: one-time plans and add-on plans become products with one price, with everything that pointed at them following.
RSpec.describe BetterTogether::Billing::Products::ConvertPlans do
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:attrs) { { processor: nil, accepted_payment_methods: %w[cash], currency: 'USD' } }
  let(:connection) { ActiveRecord::Base.connection }
  let(:plans) { BetterTogether::Billing::Plan }
  let(:links) { described_class.link_class }
  let(:primary) { create(:better_together_billing_plan, :unlinked, **attrs, billing_interval: 'month', amount_cents: 2000) }
  let(:lifetime) do
    create(:better_together_billing_plan, :unlinked, **attrs, billing_interval: 'one_time', amount_cents: 9000, name: 'Founder pass',
                                                              listed: true, participant_summary: 'Once, for good.')
  end
  let(:extra) { legacy_add_on(amount_cents: 700, name: 'Extra seat') }
  let(:any_plan_extra) { legacy_add_on(amount_cents: 300) }

  # The database before this change had a plan `add_on` flag, the link table and one-time plans. They are put back for these
  # examples (the change is rolled back with the example), since the code that used them is gone.
  before do
    connection.add_column :better_together_billing_plans, :add_on, :boolean, null: false, default: false
    connection.execute(<<~SQL.squish)
      CREATE TABLE better_together_billing_plan_add_ons (
        id uuid PRIMARY KEY DEFAULT gen_random_uuid(), lock_version integer NOT NULL DEFAULT 0,
        created_at timestamp NOT NULL DEFAULT now(), updated_at timestamp NOT NULL DEFAULT now(),
        platform_id uuid NOT NULL, plan_id uuid NOT NULL, add_on_id uuid NOT NULL)
    SQL
    [plans, links].each(&:reset_column_information)
    [primary, lifetime, extra, any_plan_extra]
    lifetime.plan_grants.create!(platform_id: host_platform.id, kind: 'quota_allowance',
                                 parameters: { 'quota_type' => 'media_storage', 'amount' => 1000 })
    links.create!(platform_id: host_platform.id, plan_id: primary.id, add_on_id: extra.id)
  end

  after { [plans, links].each(&:reset_column_information) }

  def legacy_add_on(**)
    plan = create(:better_together_billing_plan, :unlinked, **attrs, billing_interval: 'one_time', **)
    plans.where(id: plan.id).update_all(add_on: true) # rubocop:disable Rails/SkipsModelValidations
    plan
  end

  def buy(item)
    order = place_order(purpose: 'one_time', payment_method: 'cash', line_items: [{ purchasable: item }])
    pay_manually(order)
    follow_up
    order.reload
  end

  describe 'a one-time plan' do
    let!(:order) do
      buy(lifetime).tap do |paid|
        host_platform.billing_entitlements.create!(plan: lifetime, beneficiary: buyer, order: paid, starts_at: Time.current)
      end
    end
    let(:product) { host_platform.billing_products.find_by!(identifier: lifetime.identifier) }

    before { described_class.call }

    it 'becomes a product with the same name, listing and one price of the same amount' do
      expect(product).to have_attributes(name: 'Founder pass', summary: 'Once, for good.', listed: true, lifetime: 'until_used')
      expect(product.prices.sole).to have_attributes(amount_cents: 9000, currency: 'USD', active: true)
    end

    it 'moves what it included to the product' do
      expect(product.grants.pluck(:kind)).to eq(['quota_allowance'])
    end

    it 'points the lines of past orders at the price and keeps their amounts' do
      line = order.line_items.sole.reload
      expect(line.purchasable).to eq(product.prices.sole)
      expect(line.unit_amount_cents).to eq(9000)
    end

    it 'moves the buyer entitlement to the product without changing its status' do
      entitlement = host_platform.billing_entitlements.find_by!(order_id: order.id)
      expect(entitlement).to have_attributes(product_id: product.id, plan_id: nil, status: 'active')
    end

    it 'removes the plan' do
      expect(BetterTogether::Billing::Plan.exists?(lifetime.id)).to be(false)
    end
  end

  describe 'an add-on' do
    before { described_class.call }

    it 'needs the plans it extended, as a rule on its product' do
      product = host_platform.billing_products.find_by!(identifier: extra.identifier)
      rule = BetterTogether::Billing::PurchaseRequirement.for_dependent(product).sole
      expect(rule).to have_attributes(prerequisite: primary, met_by: 'either')
    end

    it 'needs any plan when it named none' do
      product = host_platform.billing_products.find_by!(identifier: any_plan_extra.identifier)
      expect(BetterTogether::Billing::PurchaseRequirement.for_dependent(product).sole).to have_attributes(prerequisite_kind: 'plan')
    end

    it 'leaves a subscription plan alone' do
      expect(BetterTogether::Billing::Plan.exists?(primary.id)).to be(true)
    end
  end

  it 'reports what moved and does nothing the second time' do
    expect(described_class.call).to have_attributes(converted: 3, skipped: [], requirements: 2)
    expect(described_class.call).to have_attributes(converted: 0, requirements: 0)
  end

  it 'changes nothing on a dry run' do
    result = described_class.call(dry_run: true)

    expect(result).to have_attributes(converted: 3, dry_run: true)
    expect(BetterTogether::Billing::Plan.exists?(lifetime.id)).to be(true)
    expect(host_platform.billing_products.exists?(identifier: lifetime.identifier)).to be(false)
  end

  it 'rolls everything back when the counts do not match' do
    converter = described_class.new
    allow(converter).to receive(:verify!).and_raise(described_class::Mismatch, 'boom')
    allow(described_class).to receive(:new).and_return(converter)

    expect { described_class.call }.to raise_error(described_class::Mismatch)
    expect(BetterTogether::Billing::Plan.exists?(lifetime.id)).to be(true)
    expect(host_platform.billing_products.exists?(identifier: lifetime.identifier)).to be(false)
  end
end
