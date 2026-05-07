# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::CommunityBillings' do
  include ActiveJob::TestHelper

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
    clear_enqueued_jobs
    sign_in platform_manager
  end

  describe 'GET /:locale/c/:community_id/billing' do
    it 'renders the billing page and plan catalog' do
      get better_together.community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Community Billing')
      expect(response.body).to include('Stewardship')
    end

    it 'synchronizes a checkout session when one is returned from Stripe' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      sync_result = BetterTogether::Billing::StripeCheckoutSessionSync::Result.new(
        synced: true,
        billable_owner: community,
        beneficiary: community,
        reason: :synced
      )
      sync_service = instance_double(BetterTogether::Billing::StripeCheckoutSessionSync, call: sync_result)

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)
      allow(BetterTogether::Billing::StripeCheckoutSessionSync).to receive(:new).and_return(sync_service)

      get better_together.community_billing_path(community, locale:, checkout_session_id: 'cs_test_123')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Stripe checkout was synchronized successfully.')
      expect(sync_service).to have_received(:call).with(checkout_session_id: 'cs_test_123', billable_owner: community, beneficiary: community)
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
      expect(processor).to have_received(:checkout).with(
        hash_including(
          mode: 'subscription',
          allow_promotion_codes: true,
          success_url: a_string_including('{CHECKOUT_SESSION_ID}'),
          cancel_url: a_string_excluding('{CHECKOUT_SESSION_ID}')
        )
      )
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

  describe 'POST /:locale/c/:community_id/billing/reconcile' do
    it 'queues a reconciliation job and redirects to billing' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)

      expect do
        post better_together.reconcile_community_billing_path(community, locale:)
      end.to have_enqueued_job(BetterTogether::Billing::ReconcileStripeBillableOwnerBillingJob).with(community.class.name, community.id)

      expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
    end
  end
end
