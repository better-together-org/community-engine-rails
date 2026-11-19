# frozen_string_literal: true

require 'rails_helper'

# A person redeems a promotion code from their credit page.
RSpec.describe BetterTogether::Billing::PromotionRedemptionsController do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }
  let(:made) do
    BetterTogether::Billing::Promotions::Create.call(platform: host_platform, actor: steward, name: 'Spring', amount_cents: 1500,
                                                     currency: 'USD')
  end

  def redemptions_path = better_together.billing_promotion_redemptions_path(locale:)
  def credit_path = better_together.billing_credit_path(locale:)

  before { allow(Rails).to receive(:cache).and_return(memory_cache) }

  it 'sends a visitor to sign in' do
    post redemptions_path, params: { promotion_code: made.code }

    expect(response).to have_http_status(:found)
    expect(made.promotion.reload.redemptions_count).to eq(0)
  end

  context 'when signed in' do
    before { sign_in buyer_user }

    it 'adds the credit and goes back to the credit page' do
      post redemptions_path, params: { promotion_code: made.code }

      expect(response).to redirect_to(credit_path)
      follow_redirect!
      expect_html_content(I18n.t('better_together.billing.promotions.redeemed'))
      account = host_platform.billing_credit_accounts.find_by(holder: buyer, currency: 'USD')
      expect(account.balance_cents).to eq(1500)
    end

    it 'does not put the code in the address it goes back to, or in the page' do
      post redemptions_path, params: { promotion_code: made.code }

      expect(response.location).not_to include(made.code.delete('-'))
      follow_redirect!
      expect(response.body).not_to include(made.code)
    end

    it 'gives one answer to a wrong code, one already used and one that has run out' do
      post redemptions_path, params: { promotion_code: 'NOPE-NOPE-NOPE-NOPE' }
      wrong = flash[:alert]
      post redemptions_path, params: { promotion_code: made.code }
      post redemptions_path, params: { promotion_code: made.code }
      used = flash[:alert]

      expect(wrong).to eq(I18n.t('better_together.billing.promotions.invalid'))
      expect(used).to eq(wrong)
      expect(host_platform.billing_credit_accounts.find_by(holder: buyer).balance_cents).to eq(1500)
    end

    it 'filters the code from the logs' do
      expect(Rails.application.config.filter_parameters).to include(:promotion_code)
    end
  end

  it 'is a 404 while billing is not switched on' do
    sign_in buyer_user
    allow(BetterTogether::Billing).to receive(:enabled?).and_return(false)

    post redemptions_path, params: { promotion_code: made.code }

    expect(response).to have_http_status(:not_found)
  end
end
