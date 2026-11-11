# frozen_string_literal: true

require 'rails_helper'

# Extras on a plan's order: add-ons are one-time, grant-free, paid by local methods, and never bought alone.
RSpec.describe 'Checkout add-ons' do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:member) { find_or_create_test_user("addon-member-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }
  let(:plan_attrs) do
    { processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time', currency: 'USD' }
  end
  let(:plan) { create(:better_together_billing_plan, :unlinked, **plan_attrs, amount_cents: 2500) }
  let(:add_on) { create(:better_together_billing_plan, :unlinked, **plan_attrs, amount_cents: 700, add_on: true) }

  before do
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    sign_in member
  end

  def new_path(plan_id: plan.id, **params) = better_together.new_billing_checkout_path(locale:, plan_id:, **params)

  it 'lists the add-ons beside the plan' do
    add_on
    get new_path

    expect(response.body).to include('billing-checkout-add-ons', "id=\"#{ActionView::RecordIdentifier.dom_id(add_on, :add_on)}\"")
  end

  it 'adds a ticked add-on to the order summary' do
    get new_path(add_on_ids: [add_on.id])

    expect(response.body).to include('billing-checkout-subtotal')
    expect(response.body).to include('$32.00')
  end

  it 'does not let an add-on be bought on its own' do
    get new_path(plan_id: add_on.id)

    expect(response).to have_http_status(:not_found)
  end

  it 'leaves an add-on out of the public catalog and offers' do
    policy = BetterTogether::Billing::PlanPolicy.new(member, add_on)
    Current.platform = host_platform

    expect([policy.catalog_show?, policy.offer?]).to eq([false, false])
  ensure
    Current.platform = nil
  end

  it 'places one order with a line for the plan and one for the add-on' do
    agreements = BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform)
    agreements.each_value { |agreement| agreement.update!(lifecycle_state: 'active') }
    address = create_billing_address_for(member.person)
    ticks = BetterTogether::Agreement.all.to_h do |a|
      [BetterTogether::ApplicationController.helpers.agreement_acceptance_param_name(a), '1']
    end

    post better_together.billing_checkout_path(locale:),
         params: { plan_id: plan.id, payment_method: 'cash', add_on_ids: [add_on.id], **billing_address_params(address) }.merge(ticks)

    order = BetterTogether::Billing::Order.order(:created_at).last
    expect(order.line_items.map(&:purchasable)).to contain_exactly(plan, add_on)
  end

  it 'hides an add-on the buyer is not in the audience for' do
    add_on.update!(restricted_to_members: true)
    get new_path

    expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(add_on, :add_on))
  end

  describe 'Plan rules' do
    it 'refuses a recurring add-on' do
      recurring = build(:better_together_billing_plan, platform: host_platform, add_on: true, billing_interval: 'month')

      expect(recurring).not_to be_valid
      expect(recurring.errors.details.values.flatten.pluck(:error)).to include(:add_on_cannot_renew)
    end
  end
end
