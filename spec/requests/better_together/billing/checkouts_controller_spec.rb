# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::CheckoutsController do
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:member) { find_or_create_test_user("checkout-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:buyer) { member.person }
  let(:buyer_address) { create_billing_address_for(buyer) }
  # Paid for once, by cash only: no online processor.
  let(:cash_plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time',
                                                     currency: 'USD', amount_cents: 2500)
  end
  let(:agreements) { BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform) }

  def new_checkout_path(**params) = better_together.new_billing_checkout_path(locale:, plan_id: cash_plan.id, **params)
  def checkout_path = better_together.billing_checkout_path(locale:)

  def enable_cash
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
  end

  def activate_agreements = agreements.each_value { |agreement| agreement.update!(lifecycle_state: 'active') }

  # Like post_checkout, with the address parameters replaced.
  def post_checkout_with(**address_params, &)
    ticks = BetterTogether::Agreement.all.to_h { |a| [BetterTogether::ApplicationController.helpers.agreement_acceptance_param_name(a), '1'] }
    post checkout_path, params: { plan_id: cash_plan.id, payment_method: 'cash', **address_params }.merge(ticks)
  end

  def post_checkout(method: 'cash', accepted: nil, plan: cash_plan)
    ids = accepted || BetterTogether::Billing::Checkout::AgreementGate.new(platform: host_platform, purpose: 'one_time', signer: buyer,
                                                                           purchasables: [plan],
                                                                           payment_method: method).missing.map(&:id)
    # The boxes are the shared agreement mechanism's: one `<identifier>_agreement=1` parameter per ticked agreement.
    ticks = BetterTogether::Agreement.where(id: ids).to_h { |agreement| [BetterTogether::ApplicationController.helpers.agreement_acceptance_param_name(agreement), '1'] }
    post checkout_path, params: { plan_id: plan.id, payment_method: method, **billing_address_params(buyer_address) }.merge(ticks)
  end

  it 'sends a visitor to sign in' do
    get new_checkout_path

    expect(response).to have_http_status(:found)
  end

  context 'when signed in' do
    before { sign_in member }

    describe 'GET new' do
      let(:zone_for) do
        ->(region) { create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA', region_code: region) }
      end

      it 'lists the ways to pay and says why one is not available' do
        enable_cash

        get new_checkout_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('billing-checkout-page', 'billing-checkout-summary', 'billing-checkout-methods',
                                         'billing-checkout-method-cash',
                                         'billing-checkout-continue-btn')
        expect(response.body).not_to include('billing-agreement-review')
      end

      it 'shows the tax and total for the chosen billing address', :aggregate_failures do
        enable_cash
        buyer_address
        create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA')
        zone = create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA', region_code: 'NL')
        create(:better_together_billing_tax_rate, platform: host_platform, tax_zone: zone, label: 'HST', rate: 0.15)

        get new_checkout_path

        expect(response.body).to include('billing-summary-checkout', 'billing-summary-checkout-tax-0', 'billing-summary-checkout-total',
                                         '$28.75')
        expect(response.body).not_to include('billing-checkout-tax-note')
      end

      it 'follows the address picked: another saved address gets its own tax', :aggregate_failures do
        enable_cash
        buyer_address
        create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA')
        create(:better_together_billing_tax_rate, platform: host_platform, label: 'HST', rate: 0.15,
                                                  tax_zone: zone_for.call('NL'))
        create(:better_together_billing_tax_rate, platform: host_platform, label: 'PST', rate: 0.10,
                                                  tax_zone: zone_for.call('BC'))
        other = create_billing_address_for(buyer, region: 'BC', settlement_name: 'Vancouver')

        get new_checkout_path(billing_address_id: other.id)

        expect(response.body).to include('$27.50')
        expect(response.body).not_to include('$28.75')
      end

      it 'promises no tax for a new address, and says it is worked out from the address entered', :aggregate_failures do
        enable_cash
        buyer_address
        create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA')
        create(:better_together_billing_tax_rate, platform: host_platform, label: 'HST', rate: 0.15,
                                                  tax_zone: zone_for.call('NL'))

        get new_checkout_path(billing_address_id: 'new')

        expect(response.body).to include('billing-checkout-tax-note', 'billing-checkout-tax-frame')
        expect(response.body).not_to include('billing-summary-checkout-total')
        expect_html_content('the address you enter')
      end

      it 'says tax is worked out once there is an address' do
        enable_cash

        get new_checkout_path

        expect(response.body).to include('billing-checkout-tax-note')
      end

      it 'says why a method that is not switched on is not available' do
        get new_checkout_path

        expect(response.body).to include('billing-checkout-method-cash-reason', 'billing-checkout-no-methods')
      end

      it 'shows the agreements to accept once a method is chosen' do
        enable_cash
        activate_agreements

        get new_checkout_path(payment_method: 'cash')

        expect(response.body).to include('billing-checkout-form', 'billing-agreement-review',
                                         'billing-agreement-accept-one_time_purchase_agreement',
                                         'billing-agreement-accept-offline_payment_terms', 'billing-checkout-place-btn')
      end

      it 'does not offer to accept agreements that are still drafts, and says the purchase cannot be completed' do
        enable_cash
        agreements

        get new_checkout_path(payment_method: 'cash')

        expect(response.body).to include('billing-checkout-not-ready')
        expect(response.body).not_to include('billing-checkout-place-btn', 'billing-agreement-accept-')
      end

      it 'ignores a method that is not available' do
        activate_agreements

        get new_checkout_path(payment_method: 'cash')

        expect(response.body).not_to include('billing-agreement-review')
      end

      it 'is a 404 for a plan that is inactive, another platform\'s, or sold by someone else' do
        cash_plan.update!(active: false)
        get new_checkout_path
        expect(response).to have_http_status(:not_found)

        foreign = create(:better_together_billing_plan, platform: create(:better_together_platform))
        get better_together.new_billing_checkout_path(locale:, plan_id: foreign.id)
        expect(response).to have_http_status(:not_found)
      end

      it 'is a 404 while billing is off' do
        allow(BetterTogether::Billing::Configuration).to receive(:requested?).and_return(false)

        get new_checkout_path

        expect(response).to have_http_status(:not_found)
      end
    end

    describe 'POST create' do
      before do
        enable_cash
        activate_agreements
      end

      it 'records the acceptance, places the order and lands on it' do
        expect { post_checkout }.to change(BetterTogether::Billing::Order, :count).by(1)

        order = BetterTogether::Billing::Order.order(:created_at).last
        expect(response).to redirect_to(better_together.billing_order_path(order, locale:))
        expect(order).to have_attributes(buyer:, status: 'awaiting_payment', total_cents: 2500, purpose: 'one_time')
        expect(order.agreement_acceptances.map(&:agreement_identifier)).to contain_exactly('one_time_purchase_agreement',
                                                                                           'offline_payment_terms')
        expect(order.agreement_acceptances.map(&:acceptance_method).uniq).to eq(['checkout'])
      end

      it 'keeps a snapshot of the billing address on the order, and where it came from', :aggregate_failures do
        post_checkout

        order = BetterTogether::Billing::Order.order(:created_at).last
        expect(order.billing_address).to include('line1' => '1 Main St', 'country_iso' => 'CA', 'region_code' => 'NL')
        expect(order.billing_address_id).to eq(buyer_address.id)
      end

      it 'works out tax for the place of the billing address', :aggregate_failures do
        buyer_address
        create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA')
        zone = create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA', region_code: 'NL')
        create(:better_together_billing_tax_rate, platform: host_platform, tax_zone: zone, label: 'HST', rate: 0.15)

        post_checkout

        expect(BetterTogether::Billing::Order.order(:created_at).last).to have_attributes(tax_cents: 375, total_cents: 2875,
                                                                                          tax_country_iso: 'CA', tax_region_code: 'NL')
      end

      it 'keeps the snapshot when the address is edited or deleted afterwards', :aggregate_failures do
        post_checkout
        order = BetterTogether::Billing::Order.order(:created_at).last
        buyer_address.update!(line1: '99 Changed Rd')
        buyer_address.destroy!

        expect(order.reload.billing_address['line1']).to eq('1 Main St')
        expect(order.billing_address_id).to be_nil
      end

      it 'refuses, placing nothing, without a billing address', :aggregate_failures do
        ticks = BetterTogether::Agreement.all.to_h { |a| [BetterTogether::ApplicationController.helpers.agreement_acceptance_param_name(a), '1'] }

        expect { post checkout_path, params: { plan_id: cash_plan.id, payment_method: 'cash' }.merge(ticks) }
          .not_to change(BetterTogether::Billing::Order, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('billing-checkout-error')
      end

      it 'refuses another person\'s address' do
        stranger_address = create_billing_address_for(create(:better_together_person))

        expect { post_checkout_with(billing_address_id: stranger_address.id) }.not_to change(BetterTogether::Billing::Order, :count)
      end

      it 'saves a new address typed in at checkout and makes it the default', :aggregate_failures do
        country = buyer_address.country
        state = buyer_address.state
        new_address = { line1: '7 Pine', postal_code: 'A1B 2C3', country_id: country.id, state_id: state.id }

        expect { post_checkout_with(billing_address_id: 'new', billing_address: new_address, make_default_billing: '1') }
          .to change(BetterTogether::Billing::Order, :count).by(1)

        default = buyer.billing_default_addresses.billing.first
        expect(default.address.line1).to eq('7 Pine')
        expect(BetterTogether::Billing::Order.order(:created_at).last.billing_address_id).to eq(default.address_id)
      end

      it 'refuses, placing nothing, when an agreement is not ticked' do
        expect { post_checkout(accepted: []) }.not_to change(BetterTogether::Billing::Order, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('billing-checkout-error')
        expect(buyer.agreement_participants.where(acceptance_method: 'checkout')).to be_empty
      end

      it 'refuses a ticked box for an agreement that does not apply' do
        stray = create(:better_together_agreement, agreement_kind: 'transactional_agreement', platform: host_platform, identifier: 'stray')

        expect { post_checkout(accepted: [stray.id]) }.not_to change(BetterTogether::Billing::Order, :count)
      end

      it 'refuses a method the plan does not accept or the platform has not switched on' do
        expect { post_checkout(method: 'cheque') }.not_to change(BetterTogether::Billing::Order, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'refuses while the agreements are drafts, however the request is crafted' do
        agreements['one_time_purchase_agreement'].update!(lifecycle_state: 'draft')

        expect { post_checkout(accepted: [agreements['one_time_purchase_agreement'].id]) }.not_to change(BetterTogether::Billing::Order, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'needs no tick for an agreement already accepted in its current form' do
        post_checkout
        expect { post_checkout(accepted: []) }.to change(BetterTogether::Billing::Order, :count).by(1)
      end

      it 'does not place an order for a plan of another platform' do
        foreign = create(:better_together_billing_plan, platform: create(:better_together_platform))

        expect do
          post checkout_path, params: { plan_id: foreign.id, payment_method: 'cash' }
        end.not_to change(BetterTogether::Billing::Order, :count)
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
