# frozen_string_literal: true

require 'rails_helper'

# DOM contract for the confirmation step before money-moving steward actions. Each form or button form carries
# data-turbo-confirm, so the browser asks before the request is sent (a native dialog: keyboard operable and announced).
RSpec.describe 'Billing steward confirmations DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }
  let(:page) { Nokogiri::HTML(response.body) }

  def confirm_of(selector) = page.at_css(selector)&.[]('data-turbo-confirm')

  # button_to wraps its button in a form of its own, which is the element that carries the confirmation.
  def confirm_for_button(id)
    page.at_xpath("//*[@id='#{id}']/ancestor::form[1]")&.[]('data-turbo-confirm')
  end

  before { sign_in steward_user }

  describe 'the payments queue' do
    it 'asks before marking a payment received' do
      transition.claim(offline, reference: 'sent')
      get "/#{locale}/billing/offline_payments"

      expect(confirm_for_button("billing-offline-confirm-btn-#{order.id}")).to include(order.number)
    end
  end

  describe 'a sale' do
    it 'asks before marking received and before rejecting' do
      get "/#{locale}/billing/sales/#{order.id}"

      expect(confirm_of("#billing-offline-receive-form-#{offline.id}")).to include(order.number)
      expect(confirm_of("#billing-offline-reject-form-#{offline.id}")).to include(order.number)
    end

    it 'asks before clearing a cheque' do
      cheque_order = place_offline('cheque')
      cheque = offline_for(cheque_order)
      transition.receive(cheque, by: steward)

      get "/#{locale}/billing/sales/#{cheque_order.id}"

      expect(confirm_for_button("billing-offline-clear-btn-#{cheque.id}")).to include(cheque_order.number)
      expect(confirm_for_button("billing-offline-bounce-btn-#{cheque.id}")).to be_present
    end

    it 'asks before recording a refund, naming the amount that will be refunded when none is typed' do
      transition.receive(offline, by: steward)

      get "/#{locale}/billing/sales/#{order.id}"

      expect(confirm_of("#billing-sale-refund-form-#{offline.id}")).to include('45.00')
      expect(page.at_css("#billing-sale-refund-form-#{offline.id}")['data-controller']).to include('billing-confirm')
    end

    it 'asks before returning a payment to store credit' do
      host_platform.billing_processor_settings.create!(processor: 'store_credit', enabled: true, acknowledge: true, purposes: %w[one_time])
      BetterTogether::Billing::Credit::Grant.call(platform: host_platform, holder: buyer, amount_cents: 6000, currency: 'USD',
                                                  origin: 'steward_grant', actor: steward, idempotency_key: 'seed')
      credit_order = place_order(payment_method: 'store_credit')

      get "/#{locale}/billing/sales/#{credit_order.id}"

      expect(confirm_of("#billing-sale-credit-refund-form-#{credit_order.payments.sole.id}")).to include(credit_order.number)
    end
  end

  describe 'granting store credit' do
    it 'asks before giving credit, naming the person' do
      create(:better_together_person_platform_membership, joinable: host_platform, member: buyer)
      get "/#{locale}/billing/credit_accounts", params: { person_id: buyer.id }

      expect(confirm_of('#billing-credit-grant-form')).to include(buyer.name)
    end
  end
end
