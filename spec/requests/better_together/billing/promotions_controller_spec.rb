# frozen_string_literal: true

require 'rails_helper'

# Stewards make promotion codes, see them once, and switch them on and off.
RSpec.describe BetterTogether::Billing::PromotionsController do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }

  def promotions_path = better_together.billing_promotions_path(locale:)
  def new_path = better_together.new_billing_promotion_path(locale:)

  def form_params(**overrides)
    { name: 'Spring drive', amount: '15.00', currency: 'USD', credit_expires_after_days: '30', max_redemptions: '100',
      purposes: ['', 'one_time'], new_members_only: '1' }.merge(overrides)
  end

  it 'sends a visitor to sign in' do
    get promotions_path

    expect(response).to have_http_status(:found)
  end

  it 'turns a signed-in non-steward away, from the list, the form and making one' do
    sign_in buyer_user

    get promotions_path
    expect(response).not_to have_http_status(:ok)
    expect { post promotions_path, params: form_params }.not_to change(host_platform.billing_promotions, :count)
  end

  context 'when signed in as a steward' do
    before { sign_in steward_user }

    it 'lists promotions with their use and state, never a code' do
      made = BetterTogether::Billing::Promotions::Create.call(platform: host_platform, actor: steward, name: 'Autumn', amount_cents: 500,
                                                              currency: 'USD', max_redemptions: 10)

      get promotions_path

      expect(response.body).to include('billing-promotions-table', 'new-promotion-btn', ActionView::RecordIdentifier.dom_id(made.promotion))
      expect_html_content('Autumn')
      expect(response.body).not_to include(made.code, made.promotion.code_digest)
    end

    it 'says there are none' do
      get promotions_path

      expect(response.body).to include('billing-promotions-empty')
    end

    it 'shows the form' do
      get new_path

      expect(response.body).to include('billing-promotion-form', 'billing-promotion-name', 'billing-promotion-amount',
                                       'billing-promotion-save-btn')
    end

    it 'makes a promotion and shows its code once, not to be cached' do
      expect { post promotions_path, params: form_params }.to change(host_platform.billing_promotions, :count).by(1)

      promotion = host_platform.billing_promotions.sole
      expect(response).to have_http_status(:created)
      expect(response.headers['Cache-Control']).to include('no-store')
      expect(response.body).to include('billing-promotion-code-display', 'billing-promotion-code-warning')
      code = response.body[/id="billing-promotion-code-display"[^>]*>([^<]+)</, 1]
      expect(BetterTogether::Billing::Promotion.digest_for(code)).to eq(promotion.code_digest)
      expect(promotion).to have_attributes(name: 'Spring drive', amount_cents: 1500, credit_expires_after_days: 30, max_redemptions: 100,
                                           purposes: %w[one_time], new_members_only: true, created_by: steward)
    end

    it 'never shows the code again: not in the list, not in a later page' do
      post promotions_path, params: form_params
      code = response.body[/id="billing-promotion-code-display"[^>]*>([^<]+)</, 1]

      get promotions_path

      expect(response.body).not_to include(code)
    end

    it 'shows what is wrong and makes nothing when the form makes no sense' do
      expect { post promotions_path, params: form_params(amount: 'lots') }.not_to change(host_platform.billing_promotions, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('billing-promotion-errors')
    end

    it 'switches one off and on again' do
      promotion = BetterTogether::Billing::Promotions::Create.call(platform: host_platform, actor: steward, name: 'P', amount_cents: 500,
                                                                   currency: 'USD').promotion

      patch better_together.deactivate_billing_promotion_path(promotion, locale:)
      expect(promotion.reload).not_to be_active

      patch better_together.activate_billing_promotion_path(promotion, locale:)
      expect(promotion.reload).to be_active
    end

    it 'cannot touch another platform\'s promotion' do
      other = create(:better_together_platform)
      foreign = BetterTogether::Billing::Promotions::Create.call(platform: other, actor: steward, name: 'F', amount_cents: 500,
                                                                 currency: 'USD').promotion

      patch better_together.deactivate_billing_promotion_path(foreign, locale:)

      expect(response).to have_http_status(:not_found)
      expect(foreign.reload).to be_active
    end
  end
end
