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
      stripe_price_id: 'price_test_stewardship',
      metadata: {
        'participant_summary' => 'Keeps this community space online and stewarded.',
        'participant_benefits' => ['Hosted community access', 'Ongoing stewardship support'],
        'beneficiary_label' => 'Community access',
        'hosted_access_level' => 'Partner',
        'support_tier' => 'Priority',
        'community_capacity_tier' => 'Growth'
      }
    )
  end
  let!(:one_time_plan) do
    create(
      :better_together_billing_plan,
      name: 'One-time setup',
      identifier: 'one-time-setup',
      billing_interval: 'one_time',
      amount_cents: 25_000,
      stripe_price_id: 'price_test_one_time_setup'
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
      expect(response.body).to include('Keeps this community space online and stewarded.')
      expect(response.body).to include('Hosted plans available now')
      expect(response.body).not_to include('One-time setup')
    end

    it 'shows the hosted entitlement derived from the current billing subscription' do
      create(
        :better_together_billing_subscription,
        billing_plan:,
        billable_owner: community,
        beneficiary: community,
        status: 'active'
      )

      get better_together.community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Hosted plan status')
      expect(response.body).to include('Hosted plan active')
      expect(response.body).to include('Hosted access level:')
      expect(response.body).to include('Partner')
      expect(response.body).to include('Support tier:')
      expect(response.body).to include('Priority')
      expect(response.body).to include('Community capacity tier:')
      expect(response.body).to include('Growth')
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
      expect(response.body).to include('Start replacement checkout for this community')
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
      expect(response.body).to include('Start replacement checkout for this community')
      expect(response.body).to include('Start replacement checkout personally')
      expect(response.body).to include('Start replacement checkout via Collective Fund')
    end

    it 'shows merchant account status when one exists' do
      create(
        'better_together/billing/merchant_account',
        :active,
        owner: community,
        provider: 'stripe_connect'
      )

      get better_together.community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Merchant account')
      expect(response.body).to include('stripe_connect')
      expect(response.body).to include('Refresh merchant status')
    end

    it 'surfaces merchant disconnect support state on the billing page' do
      create(
        'better_together/billing/merchant_account',
        owner: community,
        provider: 'stripe_connect',
        status: 'disconnected',
        metadata: { 'deauthorized_at' => '2026-05-09T12:00:00Z' }
      )

      get better_together.community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Merchant account disconnected.')
      expect(response.body).to include('Reconnect onboarding')
    end

    it 'surfaces recent ignored billing events for operator visibility' do
      create(
        :better_together_billing_event,
        processor: 'stripe',
        event_type: 'account.updated',
        event_id: 'evt_ignored_community_123',
        billable_owner: community,
        beneficiary: community,
        processing_status: 'ignored',
        attempt_count: 1,
        last_attempted_at: 8.hours.ago
      )

      get better_together.community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Billing activity alerts')
      expect(response.body).to include('Unresolved billing drift may remain.')
      expect(response.body).to include('older than one reconciliation window')
      expect(response.body).to include('account.updated')
      expect(response.body).to include('The event was recorded but did not map to a local billing update.')
    end

    it 'shows replay actions for dead-lettered billing events' do
      create(
        :better_together_billing_event,
        processor: 'stripe',
        event_type: 'invoice.payment_failed',
        event_id: 'evt_dead_letter_community_123',
        billable_owner: community,
        beneficiary: community,
        processing_status: 'dead_lettered',
        dead_lettered_at: 1.hour.ago,
        dead_letter_reason: 'repeated_failures',
        payload: {
          'id' => 'evt_dead_letter_community_123',
          'type' => 'invoice.payment_failed',
          'data' => { 'object' => { 'id' => 'in_dead_letter_community_123', 'object' => 'invoice' } }
        }
      )

      get better_together.community_billing_path(community, locale:)

      expect(response.body).to include('Dead-lettered billing events need review.')
      expect(response.body).to include('Replay event')
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
      processor = instance_double(Pay::Stripe::Customer)
      checkout_session = instance_double(Stripe::Checkout::Session, url: 'https://checkout.stripe.test/community-session')

      allow(BetterTogether::Community).to receive_messages(
        friendly: friendly_scope,
        all: [community, sponsor_community]
      )
      allow(sponsor_community).to receive(:set_payment_processor).with(:stripe).and_return(processor)
      allow(processor).to receive(:checkout).and_return(checkout_session)

      post better_together.checkout_community_billing_path(community, locale:),
           params: {
             billing_plan_id: billing_plan.id,
             checkout_as: 'community',
             billable_owner_community_id: sponsor_community.id
           }

      expect(response).to redirect_to('https://checkout.stripe.test/community-session')
      expect(processor).to have_received(:checkout).with(
        hash_including(
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
      processor = instance_double(Pay::Stripe::Customer)
      portal_session = instance_double(Stripe::BillingPortal::Session, url: 'https://billing.stripe.test/sponsored')
      billing_subscription = build_stubbed(
        :better_together_billing_subscription,
        billable_owner: sponsor,
        beneficiary: community
      )
      subscription_scope = instance_double(ActiveRecord::Relation)

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)
      allow(community).to receive(:billing_subscriptions).and_return(subscription_scope)
      allow(subscription_scope).to receive(:order).with(updated_at: :desc).and_return([billing_subscription])
      allow(sponsor).to receive(:set_payment_processor).with(:stripe).and_return(processor)
      allow(processor).to receive(:billing_portal).and_return(portal_session)

      post better_together.portal_community_billing_path(community, locale:)

      expect(response).to redirect_to('https://billing.stripe.test/sponsored')
      expect(processor).to have_received(:billing_portal).with(
        hash_including(return_url: better_together.community_billing_url(community, locale:))
      )
    end

    it 'uses the sponsoring community billing owner when the current community subscription is community-owned' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      sponsor_community = create(:better_together_community, name: 'Shared Budget')
      processor = instance_double(Pay::Stripe::Customer)
      portal_session = instance_double(Stripe::BillingPortal::Session, url: 'https://billing.stripe.test/community-sponsored')
      billing_subscription = build_stubbed(
        :better_together_billing_subscription,
        billable_owner: sponsor_community,
        beneficiary: community
      )
      subscription_scope = instance_double(ActiveRecord::Relation)

      allow(BetterTogether::Community).to receive_messages(
        friendly: friendly_scope,
        all: [community, sponsor_community]
      )
      allow(community).to receive(:billing_subscriptions).and_return(subscription_scope)
      allow(subscription_scope).to receive(:order).with(updated_at: :desc).and_return([billing_subscription])
      allow(sponsor_community).to receive(:set_payment_processor).with(:stripe).and_return(processor)
      allow(processor).to receive(:billing_portal).and_return(portal_session)

      post better_together.portal_community_billing_path(community, locale:)

      expect(response).to redirect_to('https://billing.stripe.test/community-sponsored')
      expect(processor).to have_received(:billing_portal).with(
        hash_including(return_url: better_together.community_billing_url(community, locale:))
      )
    end

    it 'guides non-sponsor admins to take over billing when portal access is blocked' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      sponsor = create(:better_together_person)
      billing_subscription = build_stubbed(
        :better_together_billing_subscription,
        billable_owner: sponsor,
        beneficiary: community
      )
      subscription_scope = instance_double(ActiveRecord::Relation)

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)
      allow(community).to receive(:billing_subscriptions).and_return(subscription_scope)
      allow(subscription_scope).to receive(:order).with(updated_at: :desc).and_return([billing_subscription])

      post better_together.portal_community_billing_path(community, locale:)

      expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
      follow_redirect!
      expect(response.body).to include('This community subscription is billed to another owner.')
    end

    it 'persists portal failure support state on the billing subscription' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      processor = instance_double(Pay::Stripe::Customer)
      billing_subscription = create(
        :better_together_billing_subscription,
        billable_owner: community,
        beneficiary: community,
        billing_plan:
      )

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)
      allow(community).to receive(:set_payment_processor).with(:stripe).and_return(processor)
      allow(processor).to receive(:billing_portal).and_raise(StandardError, 'Stripe portal outage')

      post better_together.portal_community_billing_path(community, locale:)

      expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
      expect(billing_subscription.reload.last_portal_error_message).to eq('Stripe portal outage')

      get better_together.community_billing_path(community, locale:)
      expect(response.body).to include('Billing portal access needs attention.')
      expect(response.body).to include('Stripe portal outage')
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

  describe 'POST /:locale/c/:community_id/billing/events/:event_id/replay' do
    it 'queues replay for a dead-lettered billing event' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      billing_event = create(
        :better_together_billing_event,
        processor: 'stripe',
        event_type: 'invoice.payment_failed',
        event_id: 'evt_community_replay_123',
        billable_owner: community,
        beneficiary: community,
        processing_status: 'dead_lettered',
        dead_lettered_at: 1.hour.ago,
        dead_letter_reason: 'repeated_failures',
        payload: {
          'id' => 'evt_community_replay_123',
          'type' => 'invoice.payment_failed',
          'data' => { 'object' => { 'id' => 'in_community_replay_123', 'object' => 'invoice' } }
        }
      )

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)

      expect do
        post better_together.replay_event_community_billing_path(community, event_id: billing_event.id, locale:)
      end.to have_enqueued_job(BetterTogether::Billing::ProcessStripeEventJob)

      expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
      expect(billing_event.reload.processing_status).to eq('replayed')
    end
  end

  describe 'POST /:locale/c/:community_id/billing/merchant_onboarding' do
    it 'redirects to the Stripe merchant onboarding link' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      service = instance_double(BetterTogether::Billing::MerchantAccounts::StripeConnect::CreateOnboardingLink)
      result = instance_double(
        BetterTogether::Billing::MerchantAccounts::StripeConnect::CreateOnboardingLink::Result,
        url: 'https://connect.stripe.test/community-onboarding'
      )

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)
      allow(BetterTogether::Billing::MerchantAccounts::StripeConnect::CreateOnboardingLink).to receive(:new).and_return(service)
      allow(service).to receive(:call).and_return(result)

      post better_together.merchant_onboarding_community_billing_path(community, locale:)

      expect(response).to redirect_to('https://connect.stripe.test/community-onboarding')
      expect(service).to have_received(:call).with(
        owner: community,
        refresh_url: better_together.community_billing_url(community, locale:),
        return_url: better_together.community_billing_url(community, locale:)
      )
    end
  end

  describe 'POST /:locale/c/:community_id/billing/refresh_merchant_account' do
    it 'refreshes the connected merchant account and redirects back to billing' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      merchant_account = create(
        'better_together/billing/merchant_account',
        owner: community,
        provider: 'stripe_connect'
      )
      service = instance_double(BetterTogether::Billing::MerchantAccounts::StripeConnect::RefreshAccount, call: true)

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)
      allow(BetterTogether::Billing::MerchantAccounts::StripeConnect::RefreshAccount).to receive(:new).and_return(service)

      post better_together.refresh_merchant_account_community_billing_path(community, locale:)

      expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
      expect(service).to have_received(:call).with(merchant_account:)
    end
  end

  describe 'GET /:locale/c/:community_id/billing/provision_platform' do
    it 'renders the provisioning form when entitlement is active' do
      create(
        :better_together_billing_subscription,
        billing_plan:,
        billable_owner: community,
        beneficiary: community,
        status: 'active'
      )

      get better_together.provision_platform_community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Provision hosted platform')
      expect(response.body).to include('Host URL')
      expect(response.body).to include('Hosted plan active')
    end

    it 'renders the provisioning form with attention warning when subscription is past_due' do
      create(
        :better_together_billing_subscription,
        billing_plan:,
        billable_owner: community,
        beneficiary: community,
        status: 'past_due'
      )

      get better_together.provision_platform_community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Billing attention needed')
      expect(response.body).to include('Provision hosted platform')
    end

    it 'renders the provisioning form when there is no active subscription' do
      get better_together.provision_platform_community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Provision hosted platform')
    end
  end

  describe 'POST /:locale/c/:community_id/billing/provision_platform' do
    let(:provision_params) do
      {
        platform_provision: {
          name: 'Test Hosted Platform',
          host_url: 'https://testhosted.example.com',
          time_zone: 'America/Toronto'
        }
      }
    end

    context 'when the community has an active hosted subscription' do
      before do
        create(
          :better_together_billing_subscription,
          billing_plan:,
          billable_owner: community,
          beneficiary: community,
          status: 'active'
        )
      end

      it 'calls TenantPlatformProvisioningService and redirects on success' do
        result = BetterTogether::TenantPlatformProvisioningService::Result.new(
          BetterTogether::Platform.new(host_url: 'https://testhosted.example.com'),
          nil, nil, nil, []
        )
        allow(BetterTogether::TenantPlatformProvisioningService).to receive(:call).and_return(result)

        post better_together.provision_platform_community_billing_path(community, locale:),
             params: provision_params

        expect(BetterTogether::TenantPlatformProvisioningService).to have_received(:call).with(
          name: 'Test Hosted Platform',
          host_url: 'https://testhosted.example.com',
          time_zone: 'America/Toronto'
        )
        expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
        expect(flash[:notice]).to include('testhosted.example.com')
      end

      it 're-renders the form when provisioning fails' do
        result = BetterTogether::TenantPlatformProvisioningService::Result.new(
          nil, nil, nil, nil, ['Host URL has already been taken']
        )
        allow(BetterTogether::TenantPlatformProvisioningService).to receive(:call).and_return(result)

        post better_together.provision_platform_community_billing_path(community, locale:),
             params: provision_params

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('Provision hosted platform')
      end
    end

    context 'when the community has no active subscription' do
      it 'blocks provisioning and redirects to billing with an alert' do
        allow(BetterTogether::TenantPlatformProvisioningService).to receive(:call)

        post better_together.provision_platform_community_billing_path(community, locale:),
             params: provision_params

        expect(BetterTogether::TenantPlatformProvisioningService).not_to have_received(:call)
        expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
        follow_redirect!
        expect(response.body).to include('active hosted plan is required')
      end
    end

    context 'when the community subscription is past_due' do
      it 'blocks provisioning and redirects to billing with an alert' do
        create(
          :better_together_billing_subscription,
          billing_plan:,
          billable_owner: community,
          beneficiary: community,
          status: 'past_due'
        )
        allow(BetterTogether::TenantPlatformProvisioningService).to receive(:call)

        post better_together.provision_platform_community_billing_path(community, locale:),
             params: provision_params

        expect(BetterTogether::TenantPlatformProvisioningService).not_to have_received(:call)
        expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
        follow_redirect!
        expect(response.body).to include('active hosted plan is required')
      end
    end
  end
end
