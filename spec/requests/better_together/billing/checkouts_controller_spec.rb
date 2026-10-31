# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::CheckoutsController do
  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:member) { find_or_create_test_user("checkout-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:buyer) { member.person }
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

  def post_checkout(method: 'cash', accepted: nil, plan: cash_plan)
    ids = accepted || BetterTogether::Billing::Checkout::AgreementGate.new(platform: host_platform, purpose: 'one_time', signer: buyer,
                                                                           purchasables: [plan],
                                                                           payment_method: method).missing.map(&:id)
    post checkout_path, params: { plan_id: plan.id, payment_method: method, accepted_agreement_ids: ids }
  end

  it 'sends a visitor to sign in' do
    get new_checkout_path

    expect(response).to have_http_status(:found)
  end

  context 'when signed in' do
    before { sign_in member }

    describe 'GET new' do
      it 'lists the ways to pay and says why one is not available' do
        enable_cash

        get new_checkout_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('billing-checkout-page', 'billing-checkout-summary', 'billing-checkout-methods',
                                         'billing-checkout-method-cash',
                                         'billing-checkout-continue-btn')
        expect(response.body).not_to include('billing-agreement-review')
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
