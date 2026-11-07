# frozen_string_literal: true

require 'rails_helper'

# A steward finds a person's credit by exact handle, sees the ledger, and gives credit.
RSpec.describe BetterTogether::Billing::CreditAccountsController do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:credit) { BetterTogether::Billing::Credit }

  def accounts_path(**) = better_together.billing_credit_accounts_path(locale:, **)
  def account_path(account) = better_together.billing_credit_account_path(account, locale:)

  def give(holder, cents, **attrs)
    credit::Grant.call(platform: host_platform, holder:, amount_cents: cents, currency: 'USD', origin: 'steward_grant', actor: steward,
                       idempotency_key: SecureRandom.uuid, **attrs)
  end

  it 'sends a visitor to sign in' do
    get accounts_path

    expect(response).to have_http_status(:found)
  end

  it 'turns a signed-in non-steward away' do
    sign_in buyer_user

    get accounts_path

    expect(response).not_to have_http_status(:ok)
  end

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'does not run more queries per extra account with a balance' do
      count_queries = lambda do
        count = 0
        counter = lambda do |*, payload|
          count += 1 unless %w[SCHEMA TRANSACTION].include?(payload[:name]) || payload[:sql].match?(/\A(BEGIN|COMMIT|SAVEPOINT|RELEASE)/)
        end
        ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { get accounts_path }
        count
      end
      give(buyer, 1500)
      count_queries.call # warm up
      before_count = count_queries.call
      4.times { give(create(:better_together_person), 1000) }

      expect(count_queries.call).to be <= before_count + 1
    end

    it 'lists accounts that hold a balance, and the lookup form' do
      give(buyer, 1500)

      get accounts_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-credit-accounts-page', 'billing-credit-lookup-form', 'billing-credit-lookup-handle',
                                       'billing-credit-accounts-table')
      expect_html_content(buyer.name)
    end

    it 'finds a person by their exact handle and offers to give them credit' do
      get accounts_path(handle: other_buyer.identifier)

      expect(response.body).to include('billing-credit-holder', 'billing-credit-grant-form', 'billing-credit-grant-amount',
                                       'billing-credit-grant-btn')
      expect_html_content(other_buyer.name)
    end

    it 'finds no one from part of a handle, so it cannot be used to browse people' do
      get accounts_path(handle: other_buyer.identifier[0, 4])

      expect(response.body).to include('billing-credit-lookup-failed')
      expect(response.body).not_to include('billing-credit-grant-form')
    end

    it 'says the same for a handle that does not exist' do
      get accounts_path(handle: 'nobody-by-this-name')

      expect(response.body).to include('billing-credit-lookup-failed')
    end

    it 'shows an account\'s lots and entries, with who gave it' do
      lot = give(buyer, 1500, note: 'Thanks for volunteering')
      account = lot.account

      get account_path(account)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("id=\"#{ActionView::RecordIdentifier.dom_id(account, :lots)}\"",
                                       "id=\"#{ActionView::RecordIdentifier.dom_id(account, :history)}\"")
      expect_html_content('Thanks for volunteering')
      expect_html_content(steward.name)
    end

    it 'is a 404 for another platform\'s account' do
      other = create(:better_together_platform)
      lot = credit::Grant.call(platform: other, holder: buyer, amount_cents: 100, currency: 'USD', origin: 'steward_grant', actor: steward,
                               idempotency_key: 'x')

      get account_path(lot.account)

      expect(response).to have_http_status(:not_found)
    end
  end
end
