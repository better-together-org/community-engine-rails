# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::CommunityBillings' do
  let(:locale) { I18n.default_locale }
  let(:platform_manager) do
    find_or_create_test_user("community-billing-manager-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager)
  end
  let(:community) { create(:better_together_community) }
  let!(:billing_plan) do
    create(
      :better_together_billing_plan,
      name: 'Stewardship',
      identifier: 'stewardship',
      amount_cents: 12_500,
      stripe_price_id: 'price_test_stewardship'
    )
  end

  before do
    sign_in platform_manager
  end

  describe 'GET /:locale/c/:community_id/billing' do
    it 'renders the billing page and plan catalog' do
      get better_together.community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Community Billing')
      expect(response.body).to include('Stewardship')
    end
  end

  describe 'POST /:locale/c/:community_id/billing/checkout' do
    it 'redirects to a hosted Stripe checkout session' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      processor = instance_double(Pay::Stripe::Customer)
      checkout_session = instance_double(Stripe::Checkout::Session, url: 'https://checkout.stripe.test/session')

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)
      allow(community).to receive(:set_payment_processor).with(:stripe).and_return(processor)
      allow(processor).to receive(:checkout).and_return(checkout_session)

      post better_together.checkout_community_billing_path(community, locale:), params: { billing_plan_id: billing_plan.id }

      expect(response).to redirect_to('https://checkout.stripe.test/session')
      expect(processor).to have_received(:checkout).with(hash_including(mode: 'subscription', allow_promotion_codes: true))
    end
  end

  describe 'POST /:locale/c/:community_id/billing/portal' do
    it 'redirects to the Stripe billing portal' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      processor = instance_double(Pay::Stripe::Customer)
      portal_session = instance_double(Stripe::BillingPortal::Session, url: 'https://billing.stripe.test/session')

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)
      allow(community).to receive(:set_payment_processor).with(:stripe).and_return(processor)
      allow(processor).to receive(:billing_portal).and_return(portal_session)

      post better_together.portal_community_billing_path(community, locale:)

      expect(response).to redirect_to('https://billing.stripe.test/session')
    end
  end
end
