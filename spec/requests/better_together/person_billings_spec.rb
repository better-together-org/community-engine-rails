# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PersonBillings' do
  include ActiveJob::TestHelper

  let(:locale) { I18n.default_locale }
  let(:user) do
    find_or_create_test_user("person-billing-user-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :user)
  end
  let(:person) { user.person }
  let!(:billing_plan) do
    create(
      :better_together_billing_plan,
      name: 'Personal Support',
      identifier: 'personal-support',
      amount_cents: 5_000,
      stripe_price_id: 'price_test_personal_support',
      metadata: {
        'eligible_billable_owner_types' => ['person'],
        'participant_summary' => 'Supports your participation and any communities you sponsor.',
        'participant_benefits' => ['Personal hosted access', 'Community sponsorship support'],
        'beneficiary_label' => 'Personal access'
      }
    )
  end
  let!(:one_time_plan) do
    create(
      :better_together_billing_plan,
      name: 'One-time donation',
      identifier: 'one-time-donation',
      billing_interval: 'one_time',
      amount_cents: 2_500,
      stripe_price_id: 'price_test_one_time_donation',
      metadata: { 'eligible_billable_owner_types' => ['person'] }
    )
  end

  before do
    clear_enqueued_jobs
    sign_in user
  end

  describe 'GET /:locale/p/:person_id/billing' do
    it 'renders the billing page and plan catalog' do
      get better_together.person_billing_path(person, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Personal Billing')
      expect(response.body).to include('Personal Support')
      expect(response.body).to include('Supports your participation and any communities you sponsor.')
      expect(response.body).to include('Hosted plans available now')
      expect(response.body).not_to include('One-time donation')
    end

    it 'shows community subscriptions that this person sponsors' do
      sponsored_community = create(:better_together_community, name: 'Mutual Aid Circle')
      create(
        :better_together_billing_subscription,
        billable_owner: person,
        beneficiary: sponsored_community,
        billing_plan:
      )

      get better_together.person_billing_path(person, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sponsored communities')
      expect(response.body).to include('Mutual Aid Circle')
      expect(response.body).to include('Manage billing')
    end

    it 'shows merchant account status when one exists' do
      create(
        'better_together/billing/merchant_account',
        :person_owned,
        :active,
        owner: person,
        provider: 'stripe_connect'
      )

      get better_together.person_billing_path(person, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Merchant account')
      expect(response.body).to include('stripe_connect')
      expect(response.body).to include('Refresh merchant status')
    end

    it 'surfaces merchant disconnect support state on the billing page' do
      create(
        'better_together/billing/merchant_account',
        :person_owned,
        owner: person,
        provider: 'stripe_connect',
        status: 'disconnected',
        metadata: { 'deauthorized_at' => '2026-05-09T12:00:00Z' }
      )

      get better_together.person_billing_path(person, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Merchant account disconnected.')
      expect(response.body).to include('Reconnect onboarding')
    end

    it 'surfaces recent failed billing events for operator visibility' do
      create(
        :better_together_billing_event,
        processor: 'stripe',
        event_type: 'invoice.payment_failed',
        event_id: 'evt_failed_person_123',
        billable_owner: person,
        beneficiary: person,
        processing_status: 'failed',
        error_message: 'Card was declined',
        attempt_count: 3,
        last_attempted_at: 8.hours.ago
      )

      get better_together.person_billing_path(person, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Billing activity alerts')
      expect(response.body).to include('Repeated webhook failures detected.')
      expect(response.body).to include('failed 3 or more times')
      expect(response.body).to include('Unresolved billing drift may remain.')
      expect(response.body).to include('invoice.payment_failed')
      expect(response.body).to include('Card was declined')
      expect(response.body).to include('3 attempts')
    end

    it 'shows replay actions for dead-lettered billing events' do
      create(
        :better_together_billing_event,
        processor: 'stripe',
        event_type: 'invoice.payment_failed',
        event_id: 'evt_dead_letter_person_123',
        billable_owner: person,
        beneficiary: person,
        processing_status: 'dead_lettered',
        dead_lettered_at: 1.hour.ago,
        dead_letter_reason: 'repeated_failures',
        payload: {
          'id' => 'evt_dead_letter_person_123',
          'type' => 'invoice.payment_failed',
          'data' => { 'object' => { 'id' => 'in_dead_letter_person_123', 'object' => 'invoice' } }
        }
      )

      get better_together.person_billing_path(person, locale:)

      expect(response.body).to include('Dead-lettered billing events need review.')
      expect(response.body).to include('Replay event')
    end

    it 'synchronizes a checkout session when one is returned from Stripe' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: person)
      sync_result = BetterTogether::Billing::StripeCheckoutSessionSync::Result.new(
        synced: true,
        billable_owner: person,
        beneficiary: person,
        reason: :synced
      )
      sync_service = instance_double(BetterTogether::Billing::StripeCheckoutSessionSync, call: sync_result)

      allow(BetterTogether::Person).to receive(:friendly).and_return(friendly_scope)
      allow(BetterTogether::Billing::StripeCheckoutSessionSync).to receive(:new).and_return(sync_service)

      get better_together.person_billing_path(person, locale:, checkout_session_id: 'cs_test_123')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Stripe checkout was synchronized successfully.')
      expect(sync_service).to have_received(:call).with(checkout_session_id: 'cs_test_123', billable_owner: person, beneficiary: person)
    end
  end

  describe 'POST /:locale/p/:person_id/billing/checkout' do
    it 'redirects to a hosted Stripe checkout session' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: person)
      processor = instance_double(Pay::Stripe::Customer)
      checkout_session = instance_double(Stripe::Checkout::Session, url: 'https://checkout.stripe.test/session')

      allow(BetterTogether::Person).to receive(:friendly).and_return(friendly_scope)
      allow(person).to receive(:set_payment_processor).with(:stripe).and_return(processor)
      allow(processor).to receive(:checkout).and_return(checkout_session)

      post better_together.checkout_person_billing_path(person, locale:), params: { billing_plan_id: billing_plan.id }

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
  end

  describe 'POST /:locale/p/:person_id/billing/portal' do
    it 'redirects to the Stripe billing portal' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: person)
      processor = instance_double(Pay::Stripe::Customer)
      portal_session = instance_double(Stripe::BillingPortal::Session, url: 'https://billing.stripe.test/session')

      allow(BetterTogether::Person).to receive(:friendly).and_return(friendly_scope)
      allow(person).to receive(:set_payment_processor).with(:stripe).and_return(processor)
      allow(processor).to receive(:billing_portal).and_return(portal_session)

      post better_together.portal_person_billing_path(person, locale:)

      expect(response).to redirect_to('https://billing.stripe.test/session')
    end

    it 'persists portal failure support state on the billing subscription' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: person)
      billing_subscription = create(
        :better_together_billing_subscription,
        billable_owner: person,
        beneficiary: person,
        billing_plan:
      )
      processor = instance_double(Pay::Stripe::Customer)

      allow(BetterTogether::Person).to receive(:friendly).and_return(friendly_scope)
      allow(person).to receive(:set_payment_processor).with(:stripe).and_return(processor)
      allow(processor).to receive(:billing_portal).and_raise(StandardError, 'Stripe portal outage')

      post better_together.portal_person_billing_path(person, locale:)

      expect(response).to redirect_to(better_together.person_billing_path(person, locale:))
      expect(billing_subscription.reload.last_portal_error_message).to eq('Stripe portal outage')

      get better_together.person_billing_path(person, locale:)
      expect(response.body).to include('Billing portal access needs attention.')
      expect(response.body).to include('Stripe portal outage')
    end
  end

  describe 'POST /:locale/p/:person_id/billing/reconcile' do
    it 'queues a reconciliation job and redirects to billing' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: person)

      allow(BetterTogether::Person).to receive(:friendly).and_return(friendly_scope)

      expect do
        post better_together.reconcile_person_billing_path(person, locale:)
      end.to have_enqueued_job(BetterTogether::Billing::ReconcileStripeBillableOwnerBillingJob).with(person.class.name, person.id)

      expect(response).to redirect_to(better_together.person_billing_path(person, locale:))
    end
  end

  describe 'POST /:locale/p/:person_id/billing/events/:event_id/replay' do
    it 'queues replay for a dead-lettered billing event' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: person)
      billing_event = create(
        :better_together_billing_event,
        processor: 'stripe',
        event_type: 'invoice.payment_failed',
        event_id: 'evt_person_replay_123',
        billable_owner: person,
        beneficiary: person,
        processing_status: 'dead_lettered',
        dead_lettered_at: 1.hour.ago,
        dead_letter_reason: 'repeated_failures',
        payload: {
          'id' => 'evt_person_replay_123',
          'type' => 'invoice.payment_failed',
          'data' => { 'object' => { 'id' => 'in_person_replay_123', 'object' => 'invoice' } }
        }
      )

      allow(BetterTogether::Person).to receive(:friendly).and_return(friendly_scope)

      expect do
        post better_together.replay_event_person_billing_path(person, event_id: billing_event.id, locale:)
      end.to have_enqueued_job(BetterTogether::Billing::ProcessStripeEventJob)

      expect(response).to redirect_to(better_together.person_billing_path(person, locale:))
      expect(billing_event.reload.processing_status).to eq('replayed')
    end
  end

  describe 'POST /:locale/p/:person_id/billing/merchant_onboarding' do
    it 'redirects to the Stripe merchant onboarding link' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: person)
      service = instance_double(BetterTogether::Billing::MerchantAccounts::StripeConnect::CreateOnboardingLink)
      result = instance_double(
        BetterTogether::Billing::MerchantAccounts::StripeConnect::CreateOnboardingLink::Result,
        url: 'https://connect.stripe.test/onboarding'
      )

      allow(BetterTogether::Person).to receive(:friendly).and_return(friendly_scope)
      allow(BetterTogether::Billing::MerchantAccounts::StripeConnect::CreateOnboardingLink).to receive(:new).and_return(service)
      allow(service).to receive(:call).and_return(result)

      post better_together.merchant_onboarding_person_billing_path(person, locale:)

      expect(response).to redirect_to('https://connect.stripe.test/onboarding')
      expect(service).to have_received(:call).with(
        owner: person,
        refresh_url: better_together.person_billing_url(person, locale:),
        return_url: better_together.person_billing_url(person, locale:)
      )
    end
  end

  describe 'POST /:locale/p/:person_id/billing/refresh_merchant_account' do
    it 'refreshes the connected merchant account and redirects back to billing' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: person)
      merchant_account = create(
        'better_together/billing/merchant_account',
        :person_owned,
        owner: person,
        provider: 'stripe_connect'
      )
      service = instance_double(BetterTogether::Billing::MerchantAccounts::StripeConnect::RefreshAccount, call: true)

      allow(BetterTogether::Person).to receive(:friendly).and_return(friendly_scope)
      allow(BetterTogether::Billing::MerchantAccounts::StripeConnect::RefreshAccount).to receive(:new).and_return(service)

      post better_together.refresh_merchant_account_person_billing_path(person, locale:)

      expect(response).to redirect_to(better_together.person_billing_path(person, locale:))
      expect(service).to have_received(:call).with(merchant_account:)
    end
  end
end
