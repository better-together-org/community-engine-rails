# frozen_string_literal: true

require 'rails_helper'

# Stewards manage the platform's subscribers.
RSpec.describe BetterTogether::Billing::SubscribersController do
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:term) { start_subscription }

  def list_path(**) = better_together.billing_subscribers_path(locale:, **)
  def show_path(record = term) = better_together.billing_subscriber_path(record, locale:)
  def action_path(action, record = term, **) = send(:"#{action}_billing_subscriber_path", record, locale:, **)

  it 'sends a visitor to sign in' do
    get list_path

    expect(response).to have_http_status(:found)
  end

  it 'turns a signed-in member away' do
    term
    sign_in buyer_user

    get list_path
    expect(response).not_to have_http_status(:ok)
    patch action_path(:cancel)
    expect(term.reload.pay_subscription.ends_at).to be_nil
  end

  context 'when signed in as a steward' do
    before do
      term
      sign_in steward_user
    end

    it 'lists subscribers with a filter for overdue, lapsed, active and ended' do
      get list_path

      expect(response.body).to include('billing-subscribers-table', 'billing-subscribers-filters', ActionView::RecordIdentifier.dom_id(term))
      %w[all overdue lapsed active ended].each { |name| expect(response.body).to include("billing-subscribers-filter-#{name}") }
      expect_html_content(buyer.name)
    end

    it 'filters to those past due' do
      get list_path(filter: 'overdue')
      expect(response.body).to include('billing-subscribers-empty')

      advance(term, at: Time.utc(2027, 2, 28, 16))
      travel_to(Time.utc(2027, 2, 28, 16)) { get list_path(filter: 'overdue') }

      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(term))
    end

    it 'shows one with its actions and what price it was sold at' do
      get show_path

      expect(response.body).to include('subscriber-actions', 'subscriber-waive-btn', 'subscriber-price-btn', 'subscriber-cancel-btn',
                                       'subscriber-cancel-now-btn', 'subscriber-extend-form',
                                       ActionView::RecordIdentifier.dom_id(term, :periods))
    end

    it 'covers the next period without payment' do
      patch action_path(:waive)

      expect(response).to redirect_to(show_path)
      expect(term.reload.periods.last).to be_waived
      expect(term.pay_subscription.current_period_end).to eq(Time.utc(2027, 3, 31, 15))
    end

    it 'gives a past due subscription more time, and refuses when it is not behind' do
      patch action_path(:extend_grace, days: 5)
      expect(flash[:alert]).to eq(I18n.t('better_together.billing.subscribers.refused'))

      advance(term, at: Time.utc(2027, 2, 28, 16))
      patch action_path(:extend_grace, days: 5)

      expect(term.reload.grace_ends_at).to be > Time.utc(2027, 3, 7, 15)
    end

    it 'cancels at the end of the period, or now' do
      patch action_path(:cancel)
      expect(term.reload.pay_subscription.ends_at).to eq(Time.utc(2027, 2, 28, 15))

      patch action_path(:cancel, now: '1')
      expect(term.reload.pay_subscription.status).to eq('canceled')
    end

    it 'moves one to the current price' do
      sub_plan.update_columns(amount_cents: 4000) # rubocop:disable Rails/SkipsModelValidations

      patch action_path(:move_to_current_price)

      expect(term.reload.unit_amount_cents).to eq(4000)
    end

    it 'is a 404 for another platform\'s subscriber' do
      other = create(:better_together_platform)
      customer = buyer.add_payment_processor(:local, platform: other).api_record
      foreign_sub = customer.subscribe(name: 'x', plan: 'x', current_period_start: Time.current, current_period_end: 1.month.from_now)
      foreign_plan = create(:better_together_billing_plan, platform: other)
      foreign = other.billing_subscription_terms.create!(pay_subscription: foreign_sub, plan: foreign_plan, payment_method: 'cash',
                                                         unit_amount_cents: 1, currency: 'USD', anchor_at: Time.current)

      get show_path(foreign)

      expect(response).to have_http_status(:not_found)
    end
  end
end
