# frozen_string_literal: true

require 'rails_helper'

# DOM contract for paying outside the platform: asserts the stable identifiers that documentation
# screenshots (spec/docs_screenshots/better_together/billing_offline_payments_spec.rb) and downstream
# tooling target. Runs in normal CI (no RUN_DOCS_SCREENSHOTS gate).
RSpec.describe 'Billing offline payments DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }

  # An order paid in parts can show several of these cards, so each one's ids end with the offline payment's id.
  def part_id(name) = "billing-offline-#{name}-#{offline.id}"

  def expect_ids(*ids)
    ids.each { |id| expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page" }
  end

  describe 'the buyer\'s order' do
    before { sign_in buyer_user }

    it 'exposes how to pay, the disclosures and the optional claim' do
      get "/#{locale}/billing/orders/#{order.id}"

      expect_ids(ActionView::RecordIdentifier.dom_id(offline), ActionView::RecordIdentifier.dom_id(offline, :status_badge),
                 *%w[heading status-message instructions amount disclosure claim-form claim-hint claim-reference claim-btn].map do |name|
                   part_id(name)
                 end)
    end

    it 'exposes the tax note on how to pay when the order carries tax' do
      create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA')
      zone = create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA', region_code: 'NL')
      create(:better_together_billing_tax_rate, platform: host_platform, tax_zone: zone, label: 'HST', rate: 0.15)
      taxed = place_offline('cash', tax_address: { country_iso: 'CA', region_code: 'NL' })

      get "/#{locale}/billing/orders/#{taxed.id}"

      expect_ids("billing-offline-tax-#{offline_for(taxed).id}")
    end

    it 'exposes the buyer\'s own note once they have claimed' do
      transition.claim(offline, reference: 'sent')

      get "/#{locale}/billing/orders/#{order.id}"

      expect_ids(part_id('claimed-note'))
    end

    it 'exposes the seller\'s reason when a payment was not accepted' do
      transition.reject(offline, by: steward, reason: 'nothing arrived')

      get "/#{locale}/billing/orders/#{order.id}"

      expect_ids(part_id('rejection-reason'))
    end
  end

  describe 'the seller\'s queue' do
    before { sign_in steward_user }

    it 'exposes the queue, each row, the claimed flag and the confirm button' do
      transition.claim(offline, reference: 'sent')

      get "/#{locale}/billing/offline_payments"

      expect_ids('billing-offline-queue-page', 'billing-offline-queue', ActionView::RecordIdentifier.dom_id(offline),
                 ActionView::RecordIdentifier.dom_id(offline, :claimed_badge), "billing-offline-confirm-btn-#{order.id}")
    end

    it 'exposes the empty message' do
      get "/#{locale}/billing/offline_payments"

      expect_ids('billing-offline-queue-empty')
    end
  end

  describe 'the seller\'s sale page' do
    before { sign_in steward_user }

    it 'exposes the details, and the receive and reject forms' do
      get "/#{locale}/billing/sales/#{order.id}"

      expect_ids(ActionView::RecordIdentifier.dom_id(offline), ActionView::RecordIdentifier.dom_id(offline, :details),
                 ActionView::RecordIdentifier.dom_id(offline, :claimed_at), ActionView::RecordIdentifier.dom_id(offline, :fee),
                 "billing-offline-receive-form-#{offline.id}", "billing-offline-confirm-btn-#{offline.id}",
                 "billing-offline-reject-form-#{offline.id}", "billing-offline-reject-btn-#{offline.id}")
    end

    it 'exposes the cheque buttons once a cheque is received' do
      cheque_order = place_offline('cheque')
      cheque = offline_for(cheque_order)
      transition.receive(cheque, by: steward)

      get "/#{locale}/billing/sales/#{cheque_order.id}"

      expect_ids("billing-offline-cheque-actions-#{cheque.id}", "billing-offline-clear-btn-#{cheque.id}",
                 "billing-offline-bounce-btn-#{cheque.id}")
    end

    it 'exposes the refund form once something was paid' do
      transition.receive(offline, by: steward)

      get "/#{locale}/billing/sales/#{order.id}"

      expect_ids(ActionView::RecordIdentifier.dom_id(offline.payment, :refund), "billing-sale-refund-form-#{offline.id}",
                 "billing-sale-refund-btn-#{offline.id}")
    end

    it 'exposes the tax note on the refund form when the order carries tax' do
      create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA')
      zone = create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA', region_code: 'NL')
      create(:better_together_billing_tax_rate, platform: host_platform, tax_zone: zone, label: 'HST', rate: 0.15)
      taxed = place_offline('cash', tax_address: { country_iso: 'CA', region_code: 'NL' })
      transition.receive(offline_for(taxed), by: steward)

      get "/#{locale}/billing/sales/#{taxed.id}"

      expect_ids(ActionView::RecordIdentifier.dom_id(offline_for(taxed).payment, :refund_tax))
    end

    it 'exposes the links to the queue and to a sale in person on the sales list' do
      get "/#{locale}/billing/sales"

      expect_ids('billing-sales-actions', 'billing-sales-offline-queue-link', 'new-walk-up-sale-btn')
    end
  end

  describe 'a sale in person' do
    before { sign_in steward_user }

    it 'exposes the form' do
      plan
      enable_offline('cash')

      get "/#{locale}/billing/walk_up_sale/new"

      expect_ids('billing-walk-up-page', 'billing-walk-up-form', 'billing-walk-up-plan', 'billing-walk-up-method', 'billing-walk-up-buyer',
                 'billing-walk-up-buyer-name', 'billing-walk-up-buyer-email', 'billing-walk-up-address', 'billing-walk-up-address-line1',
                 'billing-walk-up-address-country-name', 'billing-walk-up-agreements', 'billing-walk-up-received', 'billing-walk-up-submit')
    end

    it 'exposes the message when there is nothing to sell' do
      get "/#{locale}/billing/walk_up_sale/new"

      expect_ids('billing-walk-up-unavailable')
    end
  end
end
