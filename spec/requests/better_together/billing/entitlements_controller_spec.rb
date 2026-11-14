# frozen_string_literal: true

require 'rails_helper'

# "My access": what a person has because of a plan they pay for.
RSpec.describe BetterTogether::Billing::EntitlementsController do
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }

  def list_path = better_together.billing_entitlements_path(locale:)

  before do
    role_grant
    quota_grant(amount: 5_000)
  end

  it 'sends a visitor to sign in' do
    get list_path

    expect(response).to have_http_status(:found)
  end

  context 'when signed in as the payer' do
    let!(:term) { start_subscription }

    before { sign_in buyer_user }

    it 'shows each plan they pay for, where it stands, and its allowances with a usage meter' do
      entitlement = entitlement_for(term)

      get list_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-entitlements-page', ActionView::RecordIdentifier.dom_id(entitlement),
                                       ActionView::RecordIdentifier.dom_id(entitlement, :allowances), 'entitlement-status-badge', 'progressbar')
      expect_html_content(sub_plan.name)
      expect_html_content(I18n.t('better_together.billing.entitlements.status_active'))
    end

    it 'says when a late payment is still inside its extra time' do
      advance(term, at: Time.utc(2027, 2, 28, 16))
      travel_to(Time.utc(2027, 2, 28, 17)) do
        BetterTogether::Billing::Entitlements::Sync.subscription(term.reload)
        get list_path
      end

      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(entitlement_for(term), :grace))
    end

    it 'says there is nothing for someone who pays for nothing' do
      sign_in other_buyer_user

      get list_path

      expect(response.body).to include('billing-entitlements-empty')
    end

    it 'shows an entitlement the person pays for even when it is for someone else' do
      other = create(:better_together_person)
      paid_for = start_subscription(on_behalf_of: other, payer: other_buyer)
      sign_in other_buyer_user

      get list_path

      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(entitlement_for(paid_for)))
    end

    it 'never shows another person\'s access' do
      sign_in other_buyer_user

      get list_path

      expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(entitlement_for(term)))
    end
  end

  it 'is a 404 while billing is not switched on' do
    sign_in buyer_user
    allow(BetterTogether::Billing).to receive(:enabled?).and_return(false)

    get list_path

    expect(response).to have_http_status(:not_found)
  end
end
