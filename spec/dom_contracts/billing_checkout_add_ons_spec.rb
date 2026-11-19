# frozen_string_literal: true

require 'rails_helper'

# DOM contract for add-ons on checkout: the identifiers screenshots and tooling target.
RSpec.describe 'Billing checkout add-ons DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:member) { find_or_create_test_user("addon-dom-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }
  let(:attrs) { { processor: nil, accepted_payment_methods: %w[cash], currency: 'USD' } }
  let(:plan) { create(:better_together_billing_plan, :unlinked, :one_time, **attrs, amount_cents: 2500) }
  let(:add_on) { create(:better_together_billing_plan, :unlinked, :one_time, **attrs, amount_cents: 700, add_on: true) }
  let(:dom_id) { ->(*args) { ActionView::RecordIdentifier.dom_id(*args) } }

  before do
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true, settings: { 'instructions' => 'x' })
    sign_in member
  end

  it 'exposes the add-ons form, fieldset, hint, button and a checkbox per add-on' do
    get better_together.new_billing_checkout_path(locale: :en, plan_id: plan.id, add_on_ids: [add_on.id])

    expect(response.body).to include('id="billing-checkout-add-ons-form"', 'id="billing-checkout-add-ons"', 'id="billing-checkout-add-ons-hint"',
                                     'id="billing-checkout-add-ons-btn"', %(id="#{dom_id.call(add_on, :add_on)}"),
                                     %(id="#{dom_id.call(add_on, :checkout_line)}"), 'id="billing-checkout-subtotal"')
  end
end
