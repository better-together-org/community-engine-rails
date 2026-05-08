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

    it 'shows takeover actions when a community subscription is sponsored by a person' do
      sponsor = platform_manager.person
      Pay::Customer.create!(owner: sponsor, processor: 'stripe', processor_id: 'cus_person_takeover')
      create(
        :better_together_billing_subscription,
        billing_plan:,
        billable_owner: sponsor,
        beneficiary: community
      )

      get better_together.community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('currently sponsored by')
      expect(response.body).to include('Switch billing to this community')
    end

    it 'shows community takeover actions when a community subscription is sponsored by another community' do
      sponsor_community = create(:better_together_community, name: 'Shared Budget')
      alternate_sponsor = create(:better_together_community, name: 'Collective Fund')
      Pay::Customer.create!(owner: sponsor_community, processor: 'stripe', processor_id: 'cus_shared_budget')
      Pay::Customer.create!(owner: alternate_sponsor, processor: 'stripe', processor_id: 'cus_collective_fund')
      create(
        :better_together_billing_subscription,
        billing_plan:,
        billable_owner: sponsor_community,
        beneficiary: community
      )

      get better_together.community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Switch billing to this community')
      expect(response.body).to include('Pay personally instead')
      expect(response.body).to include('Pay via Collective Fund instead')
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
      expect(sync_service).to have_received(:call).with(checkout_session_id: 'cs_test_123')
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
          success_url: a_string_including('checkout_session_id=%7BCHECKOUT_SESSION_ID%7D'),
          cancel_url: satisfy { |url| !url.include?('checkout_session_id=') }
        )
      )
    end

    it 'supports person-sponsored checkout for a community beneficiary' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      processor = instance_double(Pay::Stripe::Customer)
      checkout_session = instance_double(Stripe::Checkout::Session, url: 'https://checkout.stripe.test/session')
      sponsor = platform_manager.person

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)
      allow(sponsor).to receive(:set_payment_processor).with(:stripe).and_return(processor)
      allow(processor).to receive(:checkout).and_return(checkout_session)

      post better_together.checkout_community_billing_path(community, locale:),
           params: { billing_plan_id: billing_plan.id, checkout_as: 'person' }

      expect(response).to redirect_to('https://checkout.stripe.test/session')
      expect(processor).to have_received(:checkout).with(
        hash_including(
          client_reference_id: sponsor.id,
          metadata: hash_including(
            bt_billable_owner_type: 'BetterTogether::Person',
            bt_billable_owner_id: sponsor.id,
            bt_beneficiary_type: 'BetterTogether::Community',
            bt_beneficiary_id: community.id
          )
        )
      )
    end

    it 'supports community-sponsored checkout for another community beneficiary' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      sponsor_community = create(:better_together_community, name: 'Collective Sponsor')
      sponsor_customer = Pay::Customer.create!(
        owner: sponsor_community,
        processor: 'stripe',
        processor_id: 'cus_collective_sponsor'
      )
      checkout_session = instance_double(Stripe::Checkout::Session, url: 'https://checkout.stripe.test/community-session')

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)
      allow(Stripe::Checkout::Session).to receive(:create).and_return(checkout_session)

      post better_together.checkout_community_billing_path(community, locale:),
           params: {
             billing_plan_id: billing_plan.id,
             checkout_as: 'community',
             billable_owner_community_id: sponsor_community.id
           }

      expect(response).to redirect_to('https://checkout.stripe.test/community-session')
      expect(Stripe::Checkout::Session).to have_received(:create).with(
        hash_including(
          customer: sponsor_customer.processor_id,
          client_reference_id: sponsor_community.id,
          metadata: hash_including(
            bt_billable_owner_type: 'BetterTogether::Community',
            bt_billable_owner_id: sponsor_community.id,
            bt_beneficiary_type: 'BetterTogether::Community',
            bt_beneficiary_id: community.id
          )
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

    it 'uses the sponsor billing owner when the current community subscription is person-owned' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      sponsor = platform_manager.person
      sponsor_customer = Pay::Customer.create!(owner: sponsor, processor: 'stripe', processor_id: 'cus_sponsor_portal')
      portal_session = instance_double(Stripe::BillingPortal::Session, url: 'https://billing.stripe.test/sponsored')
      create(:better_together_billing_subscription, billable_owner: sponsor, beneficiary: community)

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)
      allow(Stripe::BillingPortal::Session).to receive(:create).and_return(portal_session)

      post better_together.portal_community_billing_path(community, locale:)

      expect(response).to redirect_to('https://billing.stripe.test/sponsored')
      expect(Stripe::BillingPortal::Session).to have_received(:create).with(
        hash_including(customer: sponsor_customer.processor_id)
      )
    end

    it 'uses the sponsoring community billing owner when the current community subscription is community-owned' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      sponsor_community = create(:better_together_community, name: 'Shared Budget')
      sponsor_customer = Pay::Customer.create!(owner: sponsor_community, processor: 'stripe', processor_id: 'cus_shared_budget_portal')
      portal_session = instance_double(Stripe::BillingPortal::Session, url: 'https://billing.stripe.test/community-sponsored')
      create(:better_together_billing_subscription, billable_owner: sponsor_community, beneficiary: community)

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)
      allow(Stripe::BillingPortal::Session).to receive(:create).and_return(portal_session)

      post better_together.portal_community_billing_path(community, locale:)

      expect(response).to redirect_to('https://billing.stripe.test/community-sponsored')
      expect(Stripe::BillingPortal::Session).to have_received(:create).with(
        hash_including(customer: sponsor_customer.processor_id)
      )
    end

    it 'guides non-sponsor admins to take over billing when portal access is blocked' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      sponsor_community = create(:better_together_community, name: 'Shared Budget')
      create(:better_together_billing_subscription, billable_owner: sponsor_community, beneficiary: community)

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)

      post better_together.portal_community_billing_path(community, locale:)

      expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
      follow_redirect!
      expect(response.body).to include('start a new checkout below to take over billing for this community')
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

    it 'queues reconciliation for the sponsored billable owner when present' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      sponsor = platform_manager.person
      create(:better_together_billing_subscription, billable_owner: sponsor, beneficiary: community)

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)

      expect do
        post better_together.reconcile_community_billing_path(community, locale:)
      end.to have_enqueued_job(BetterTogether::Billing::ReconcileStripeBillableOwnerBillingJob).with(sponsor.class.name, sponsor.id)
    end
  end
end
