# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::WalkUpSalesController do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:path) { better_together.billing_walk_up_sale_path(locale:) }
  let(:new_path) { better_together.new_billing_walk_up_sale_path(locale:) }
  let(:cash_plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time',
                                                     amount_cents: 4500, currency: 'USD')
  end
  let(:params) do
    { plan_id: cash_plan.id, payment_method: 'cash', buyer_identifier: buyer.identifier, agreements_accepted: '1' }
  end

  before do
    enable_offline('cash')
    cash_plan
    purchase_agreements_for(host_platform)
    # The buyer is a member of the platform, with a role that does not manage anything.
    viewer = BetterTogether::Role.find_by!(identifier: 'platform_analytics_viewer')
    BetterTogether::PersonPlatformMembership.find_or_create_by!(member: buyer, joinable: host_platform, role: viewer) do |membership|
      membership.status = 'active'
    end
  end

  it 'sends a visitor to sign in' do
    get new_path

    expect(response).to have_http_status(:found)
  end

  it 'turns the buyer away' do
    sign_in buyer_user

    expect { post path, params: }.not_to change(BetterTogether::Billing::Order, :count)
  end

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'shows the form with stable ids' do
      get new_path

      expect(response.body).to include('billing-walk-up-form', 'billing-walk-up-plan', 'billing-walk-up-method', 'billing-walk-up-buyer',
                                       'billing-walk-up-agreements', 'billing-walk-up-received', 'billing-walk-up-submit')
    end

    it 'says what is missing when there is nothing to sell or no method on' do
      host_platform.billing_processor_settings.update_all(enabled: false) # rubocop:disable Rails/SkipsModelValidations

      get new_path

      expect(response.body).to include('billing-walk-up-unavailable')
    end

    it 'places the order for the buyer, records the agreements as accepted in person, and leaves it waiting' do
      expect { post path, params: }.to change(BetterTogether::Billing::Order, :count).by(1)

      order = BetterTogether::Billing::Order.order(:created_at).last
      expect(response).to redirect_to(better_together.billing_sale_path(order, locale:))
      expect(order).to be_awaiting_payment
      expect(order.buyer).to eq(buyer)
      expect(order.offline_payments.first).to have_attributes(seller_assisted: true, status: 'awaiting')
      expect(order.agreement_acceptances.map(&:acceptance_method).uniq).to eq(['seller_assisted'])
    end

    it 'confirms the payment at once when the money has changed hands, and the buyer never had to do anything' do
      clear_notices
      deliver_now { post path, params: params.merge(payment_received: '1') }

      order = BetterTogether::Billing::Order.order(:created_at).last
      expect(order).to be_paid
      expect(order.offline_payments.first).to have_attributes(status: 'confirmed', claimed_at: nil, confirmed_by: steward)
      expect(kinds_for(buyer)).to include('payment_confirmed')
    end

    it 'refuses without the agreements being accepted in person, and records nothing' do
      expect { post path, params: params.merge(agreements_accepted: '0') }.not_to change(BetterTogether::Billing::Order, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('billing-walk-up-error')
    end

    it 'refuses a buyer who is not a member of this platform, and one who does not exist' do
      stranger = create(:better_together_person)

      post path, params: params.merge(buyer_identifier: stranger.identifier)
      post path, params: params.merge(buyer_identifier: 'nobody-by-this-name')

      expect(BetterTogether::Billing::Order.count).to eq(0)
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses a way of paying that is not switched on' do
      expect { post path, params: params.merge(payment_method: 'cheque') }.not_to change(BetterTogether::Billing::Order, :count)
    end

    it 'does not sell another platform\'s plan' do
      foreign = create(:better_together_billing_plan, platform: create(:better_together_platform))

      post path, params: params.merge(plan_id: foreign.id)

      expect(response).to have_http_status(:not_found)
    end
  end
end
