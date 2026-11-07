# frozen_string_literal: true

require 'rails_helper'

# Stewards see usage and choose how strictly each quota is enforced.
RSpec.describe BetterTogether::Billing::AllowancesController do
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }

  def list_path = better_together.billing_allowances_path(locale:)
  def type_path(key) = better_together.billing_allowance_path(key, locale:)

  it 'sends a visitor to sign in' do
    get list_path

    expect(response).to have_http_status(:found)
  end

  it 'turns a signed-in member away' do
    sign_in buyer_user

    get list_path
    expect(response).not_to have_http_status(:ok)
    patch type_path('media_storage'), params: { mode: 'hard' }
    expect(host_platform.reload.quota_enforcement_mode('media_storage')).to eq('shadow')
  end

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'lists each quota type with its mode, shadow unless a steward chose otherwise' do
      get list_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-allowances-page', 'billing-allowances-enforcement', 'billing-allowance-form-media_storage',
                                       'billing-allowance-form-ai_translation_tokens')
      expect(response.body).to include('<option selected="selected" value="shadow"')
    end

    it 'changes the mode of one quota type for the platform' do
      patch type_path('media_storage'), params: { mode: 'soft' }

      expect(response).to redirect_to(list_path)
      expect(host_platform.reload.quota_enforcement_mode('media_storage')).to eq('soft')
      expect(host_platform.quota_enforcement_mode('ai_translation_tokens')).to eq('shadow')
    end

    it 'refuses a mode that does not exist and a quota type that does not exist' do
      patch type_path('media_storage'), params: { mode: 'ruthless' }
      expect(flash[:alert]).to eq(I18n.t('better_together.billing.allowances.refused'))

      patch type_path('gold'), params: { mode: 'hard' }
      expect(flash[:alert]).to eq(I18n.t('better_together.billing.allowances.refused'))
      expect(host_platform.reload.quota_enforcement_mode('media_storage')).to eq('shadow')
    end

    it 'lists owners with a paid allowance, with usage' do
      quota_grant(amount: 5_000)
      term = start_subscription
      quota = BetterTogether::Quota.find_by!(owner: term.payer, quota_type: 'media_storage')

      get list_path

      expect(response.body).to include('billing-allowances-table', ActionView::RecordIdentifier.dom_id(quota))
      expect_html_content(I18n.t('better_together.billing.allowances.within'))
    end

    it 'lists a community over its limit' do
      BetterTogether::Quotas.sync_limit!(type: 'media_storage', owner: community)
      quota = BetterTogether::Quota.find_by!(owner: community, quota_type: 'media_storage')
      quota.update!(limit: 10)
      BetterTogether::Quotas.settle!(type: 'media_storage', owner: community, amount: 50, idempotency_key: 'big-use')

      get list_path

      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(quota))
      expect_html_content(I18n.t('better_together.billing.allowances.over'))
    end

    it 'says so when no one has a paid allowance or is over' do
      get list_path

      expect(response.body).to include('billing-allowances-empty')
    end
  end
end
