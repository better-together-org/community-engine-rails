# frozen_string_literal: true

RSpec::Matchers.define_negated_matcher :not_change, :change

# Store credit switched on for the host platform, a steward and helpers to give a buyer credit and to place an
# order paid with it.
RSpec.shared_context 'with store credit fixtures' do
  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'

  let(:steward) { create(:better_together_person) }
  let(:credit) { BetterTogether::Billing::Credit }

  before do
    host_platform.billing_processor_settings.create!(processor: 'store_credit', enabled: true, acknowledge: true,
                                                     purposes: %w[subscription one_time ticket exchange])
  end

  def grant_credit(amount_cents, holder: buyer, currency: 'USD', **attrs)
    credit::Grant.call(platform: host_platform, holder:, amount_cents:, currency:, origin: 'steward_grant', actor: steward,
                       idempotency_key: SecureRandom.uuid, **attrs)
  end

  def account_of(holder = buyer, currency: 'USD') = credit.find_account(platform: host_platform, holder:, currency:)

  def place_with_credit(**attrs) = place_order(payment_method: 'store_credit', **attrs)
end
