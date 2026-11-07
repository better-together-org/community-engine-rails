# frozen_string_literal: true

require 'rails_helper'

# A payer's own subscriptions that Community Engine renews.
RSpec.describe BetterTogether::Billing::SubscriptionsController do
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:term) { start_subscription }

  def list_path = better_together.billing_subscriptions_path(locale:)
  def show_path(record = term) = better_together.billing_subscription_path(record, locale:)
  def action_path(action, record = term) = send(:"#{action}_billing_subscription_path", record, locale:)

  it 'sends a visitor to sign in' do
    get list_path

    expect(response).to have_http_status(:found)
  end

  context 'when signed in as the payer' do
    before do
      term
      sign_in buyer_user
    end

    it 'lists their subscriptions with state and price' do
      get list_path

      expect(response.body).to include('billing-subscriptions-table', ActionView::RecordIdentifier.dom_id(term))
      expect_html_content(sub_plan.name)
      expect_html_content(I18n.t('better_together.billing.subscriptions.state_active'))
    end

    it 'says there are none for someone with no subscription' do
      sign_in other_buyer_user

      get list_path

      expect(response.body).to include('billing-subscriptions-empty')
    end

    it 'shows one: when it is paid through, what it costs, and each period with its invoice' do
      get show_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('subscription-through', 'subscription-price', 'subscription-method', 'subscription-cancel-btn',
                                       ActionView::RecordIdentifier.dom_id(term, :periods))
      expect_html_content(billing_amount_text = 'US$30.00')
      expect(billing_amount_text).to be_present
    end

    it 'cancels at the end of the paid period, and offers to keep it afterwards' do
      patch action_path(:cancel)

      expect(response).to redirect_to(show_path)
      expect(term.reload.pay_subscription.ends_at).to eq(Time.utc(2027, 2, 28, 15))
      get show_path
      expect(response.body).to include('subscription-resume-btn')
      expect(response.body).not_to include('subscription-cancel-btn')
    end

    it 'resumes a cancellation' do
      patch action_path(:cancel)
      patch action_path(:resume)

      expect(term.reload.pay_subscription.ends_at).to be_nil
    end

    it 'says so when there is nothing to resume' do
      patch action_path(:resume)

      expect(response).to redirect_to(show_path)
      expect(flash[:alert]).to eq(I18n.t('better_together.billing.subscriptions.cannot_resume'))
    end

    it 'never shows or changes another person\'s subscription' do
      sign_in other_buyer_user

      get show_path
      expect(response).to have_http_status(:not_found)
      patch action_path(:cancel)
      expect(response).to have_http_status(:not_found)
      expect(term.reload.pay_subscription.ends_at).to be_nil
    end

    it 'is not reached by a steward through the payer\'s pages' do
      sign_in steward_user

      get show_path

      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when the terms changed and the renewal is waiting for the payer to accept' do
    before do
      term
      sign_in buyer_user
      change_subscription_agreement
      generate_renewal(term, at: Time.utc(2027, 2, 20))
    end

    it 'shows the agreements to accept' do
      travel_to(Time.utc(2027, 2, 21)) { get show_path }

      expect(term.periods.last).to be_needs_agreement
      expect(response.body).to include('subscription-agreements-form', 'subscription-accept-btn')
    end

    it 'makes the invoice once they are all accepted, and refuses when one is left out' do
      travel_to(Time.utc(2027, 2, 21)) do
        gate = BetterTogether::Billing::Checkout::AgreementGate.new(platform: host_platform, purpose: 'subscription', signer: buyer,
                                                                    purchasables: [sub_plan], payment_method: 'cash')
        post action_path(:accept_agreements), params: { accepted_agreement_ids: [] }
        expect(term.periods.reload.last.order).to be_nil if gate.missing.any?

        post action_path(:accept_agreements), params: { accepted_agreement_ids: gate.missing.map(&:id) }
      end

      expect(term.periods.reload.last).to have_attributes(status: 'pending')
      expect(term.periods.last.order).to be_present
    end
  end

  it 'is a 404 while billing is not switched on' do
    sign_in buyer_user
    allow(BetterTogether::Billing).to receive(:enabled?).and_return(false)

    get list_path

    expect(response).to have_http_status(:not_found)
  end
end
