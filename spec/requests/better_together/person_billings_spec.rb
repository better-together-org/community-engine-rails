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
          success_url: a_string_including('{CHECKOUT_SESSION_ID}'),
          cancel_url: a_string_excluding('{CHECKOUT_SESSION_ID}')
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
end
