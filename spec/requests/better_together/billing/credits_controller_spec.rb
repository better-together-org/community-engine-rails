# frozen_string_literal: true

require 'rails_helper'

# A person's own store credit.
RSpec.describe BetterTogether::Billing::CreditsController do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:credit) { BetterTogether::Billing::Credit }

  def credit_path = better_together.billing_credit_path(locale:)

  def give(holder, cents, **attrs)
    credit::Grant.call(platform: host_platform, holder:, amount_cents: cents, currency: 'USD', origin: 'steward_grant', actor: steward,
                       idempotency_key: SecureRandom.uuid, **attrs)
  end

  it 'sends a visitor to sign in' do
    get credit_path

    expect(response).to have_http_status(:found)
  end

  context 'when signed in' do
    before { sign_in buyer_user }

    it 'says there is none when the person has no credit' do
      get credit_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-credit-page', 'billing-credit-empty')
    end

    it 'shows what can be spent, each amount with when it expires, and the history' do
      lot = give(buyer, 2500, expires_at: 10.days.from_now, purposes: %w[one_time])
      give(buyer, 1000)

      get credit_path
      account = credit.find_account(platform: host_platform, holder: buyer, currency: 'USD')

      expect(response.body).to include("id=\"#{ActionView::RecordIdentifier.dom_id(account)}\"", "id=\"#{ActionView::RecordIdentifier.dom_id(lot)}\"",
                                       "id=\"#{ActionView::RecordIdentifier.dom_id(account, :history)}\"")
      expect_html_content(I18n.t('better_together.billing.credit.usable', amount: 'US$35.00'))
      expect_html_content(I18n.t('better_together.billing.credit.origin_steward_grant'))
      expect_html_content(I18n.t('better_together.billing.credit.never_expires'))
    end

    it 'leaves out an amount that is used up' do
      lot = give(buyer, 500)
      lot.update_columns(remaining_cents: 0) # rubocop:disable Rails/SkipsModelValidations

      get credit_path

      expect(response.body).not_to include("id=\"#{ActionView::RecordIdentifier.dom_id(lot)}\"")
    end

    it 'never shows another person\'s credit' do
      lot = give(other_buyer, 9900)

      get credit_path

      expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(lot))
      expect(response.body).not_to include('99.00')
    end

    it 'never shows another platform\'s credit' do
      other = create(:better_together_platform)
      credit::Grant.call(platform: other, holder: buyer, amount_cents: 7700, currency: 'USD', origin: 'steward_grant', actor: steward,
                         idempotency_key: 'other')

      get credit_path

      expect(response.body).to include('billing-credit-empty')
    end
  end

  it 'is a 404 while billing is not switched on' do
    sign_in buyer_user
    allow(BetterTogether::Billing).to receive(:enabled?).and_return(false)

    get credit_path

    expect(response).to have_http_status(:not_found)
  end
end
