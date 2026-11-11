# frozen_string_literal: true

require 'rails_helper'

# The buyer's own billing page, and the account menu link that leads to it.
RSpec.describe BetterTogether::Billing::HubsController do
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }

  def hub_path = better_together.billing_hub_path(locale:)

  def give(holder, cents)
    BetterTogether::Billing::Credit::Grant.call(platform: host_platform, holder:, amount_cents: cents, currency: 'USD', origin: 'steward_grant',
                                                actor: steward, idempotency_key: SecureRandom.uuid)
  end

  it 'sends a visitor to sign in' do
    get hub_path

    expect(response).to have_http_status(:found)
  end

  context 'when signed in' do
    before { sign_in buyer_user }

    it 'says there is nothing yet, and still links to each full page' do
      get hub_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-hub-page', 'billing-hub-plans-empty', 'billing-hub-orders-empty', 'billing-hub-credit-empty',
                                       'billing-hub-plans-link', 'billing-hub-orders-link', 'billing-hub-credit-link', 'billing-hub-access-link')
    end

    it 'gathers the person\'s active plan, latest order, credit and access' do
      term = start_subscription
      give(buyer, 1200)

      get hub_path
      order = term.reload.periods.first.order

      ids = [term, order].map { |record| %(id="#{ActionView::RecordIdentifier.dom_id(record, :hub)}") }
      expect(response.body).to include(*ids)
      expect_html_content(sub_plan.name)
      expect_html_content('US$12.00')
      expect(response.body).not_to include('billing-hub-plans-empty', 'billing-hub-orders-empty', 'billing-hub-credit-empty')
    end

    it 'leaves out someone else\'s plan, orders and credit' do
      other = create(:better_together_person)
      term = start_subscription(payer: other)
      give(other, 900)

      get hub_path

      expect(response.body).not_to include(%(id="#{ActionView::RecordIdentifier.dom_id(term, :hub)}"))
      expect(response.body).to include('billing-hub-plans-empty', 'billing-hub-orders-empty', 'billing-hub-credit-empty')
    end

    it 'puts Billing in the account menu while billing is on' do
      get better_together.home_page_path(locale:)

      expect(response.body).to include(hub_path)
    end
  end
end
