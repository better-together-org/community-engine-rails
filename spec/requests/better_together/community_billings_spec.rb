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

  def create_owned_billing_subscription(owner:, billing_plan:, status:)
    pay_customer = create('pay/customer', owner:)
    pay_subscription = create('pay/subscription', customer: pay_customer, status:)

    create(:better_together_billing_subscription, pay_subscription:, billing_plan:)
  end

  describe 'GET /:locale/c/:community_id/billing' do
    it 'renders the billing page and plan catalog' do
      get better_together.community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Community Billing')
      expect(response.body).to include('Stewardship')
      expect(response.body).to include('Keeps this community space online and stewarded.')
      expect(response.body).to include(
        I18n.t('better_together.billing.hosted_plan_scope_heading', default: 'Hosted plans available now')
      )
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

    it 'shows a card offering to contribute to another community, listing available contribution plans' do
      create(
        :better_together_billing_plan,
        name: 'Solidarity Contribution',
        identifier: 'solidarity-contribution',
        billing_interval: 'one_time',
        amount_cents: 2_500,
        stripe_price_id: 'price_test_solidarity_contribution',
        metadata: { 'sponsorship_contribution' => true }
      )

      get better_together.community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Contribute to another community')
      expect(response.body).to include('$25.00')
    end

    it 'shows received sponsorship contributions when this community has been funded by a sponsor' do
      sponsor = create(:better_together_person)
      sponsorship = create(:better_together_billing_sponsorship, sponsor:, beneficiary: community, status: 'active')
      create(:better_together_billing_monetary_contribution, sponsorship:, amount_cents: 5_000)

      get better_together.community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('This community has received')
      expect(response.body).to include('$50.00')
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
      expect(response.body).to include(
        I18n.t('better_together.billing.merchant_disconnected_heading', default: 'Merchant account disconnected.')
      )
      expect(response.body).to include(I18n.t('better_together.billing.open_merchant_onboarding', default: 'Open merchant onboarding'))
    end

    it 'hides payout-onboarding actions from a community steward without settings-tier access' do
      facilitator = find_or_create_test_user("community-billing-facilitator-#{SecureRandom.hex(4)}@example.test",
                                             'SecureTest123!@#', :user)
      facilitator_role = BetterTogether::Role.find_by(identifier: 'community_facilitator')
      # This worktree's test database can carry a stale community_facilitator permission set
      # from an earlier seed run; assign explicitly so this reflects the role defined in source.
      facilitator_role.assign_resource_permissions(
        %w[read_community list_community create_community update_community delete_community
           invite_community_members],
        sync: true
      )
      BetterTogether::PersonCommunityMembership.create!(
        joinable: community,
        member: facilitator.person,
        role: facilitator_role,
        status: 'active'
      )
      sign_in facilitator

      get better_together.community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Merchant account')
      expect(response.body).not_to include('Refresh merchant status')
      expect(response.body).not_to include(
        I18n.t('better_together.billing.open_merchant_onboarding', default: 'Open merchant onboarding')
      )
      expect(response.body).to include(
        I18n.t(
          'better_together.billing.merchant_onboarding_admin_only_community',
          default: 'Payout onboarding for future commerce flows is managed by a community settings ' \
                   'administrator or platform steward, not by general community stewardship access.'
        )
      )
    end

    it 'still shows read-only merchant status to a community steward without settings-tier access, when an account exists' do
      create(
        'better_together/billing/merchant_account',
        :active,
        owner: community,
        provider: 'stripe_connect'
      )
      facilitator = find_or_create_test_user("community-billing-facilitator-status-#{SecureRandom.hex(4)}@example.test",
                                             'SecureTest123!@#', :user)
      facilitator_role = BetterTogether::Role.find_by(identifier: 'community_facilitator')
      facilitator_role.assign_resource_permissions(
        %w[read_community list_community create_community update_community delete_community
           invite_community_members],
        sync: true
      )
      BetterTogether::PersonCommunityMembership.create!(
        joinable: community,
        member: facilitator.person,
        role: facilitator_role,
        status: 'active'
      )
      sign_in facilitator

      get better_together.community_billing_path(community, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Merchant account')
      expect(response.body).to include('stripe_connect')
      expect(response.body).not_to include('Refresh merchant status')
      expect(response.body).not_to include(
        I18n.t('better_together.billing.open_merchant_onboarding', default: 'Open merchant onboarding')
      )
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
      expect(response.body).to include(
        I18n.t('better_together.billing.unresolved_alert_heading', default: 'Unresolved billing drift may remain.')
      )
      expect(response.body).to include(
        I18n.t(
          'better_together.billing.unresolved_alert_body',
          default: '%<count>d failed or ignored events are older than one reconciliation window (%<hours>d hours).',
          count: 1,
          hours: BetterTogether::Billing::Event::UNRESOLVED_ALERT_WINDOW / 1.hour
        )
      )
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

      expect(response.body).to include(
        I18n.t('better_together.billing.dead_letter_alert_heading', default: 'Dead-lettered billing events need review.')
      )
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
      expect(sync_service).to have_received(:call).with(checkout_session_id: 'cs_test_123', beneficiary: community)
    end
  end

  describe 'POST /:locale/c/:community_id/billing/checkout' do
    it 'redirects to a hosted Stripe checkout session' do
      checkout_session = instance_double(Stripe::Checkout::Session, url: 'https://checkout.stripe.test/session')
      Pay::Stripe::Customer.create!(owner: community, processor: 'stripe', processor_id: 'cus_community_checkout')

      allow(Stripe::Checkout::Session).to receive(:create).and_return(checkout_session)

      post better_together.checkout_community_billing_path(community, locale:), params: { billing_plan_id: billing_plan.identifier }

      expect(response).to redirect_to('https://checkout.stripe.test/session')
      expect(Stripe::Checkout::Session).to have_received(:create).with(
        hash_including(
          customer: 'cus_community_checkout',
          mode: 'subscription',
          allow_promotion_codes: true,
          success_url: satisfy do |url|
            url.include?('checkout_session_id={CHECKOUT_SESSION_ID}') &&
              url.include?('stripe_checkout_session_id={CHECKOUT_SESSION_ID}')
          end,
          cancel_url: a_string_including('stripe_checkout_session_id={CHECKOUT_SESSION_ID}')
        ),
        anything
      )
    end

    it 'disables Turbo on checkout actions that redirect to Stripe' do
      get better_together.community_billing_path(community, locale:)

      expect(response.body).to include('data-turbo="false"')
    end
  end

  describe 'POST /:locale/c/:community_id/billing/contribute' do
    let!(:contribution_plan) do
      create(
        :better_together_billing_plan,
        name: 'Solidarity Contribution',
        identifier: 'solidarity-contribution',
        billing_interval: 'one_time',
        amount_cents: 2_500,
        stripe_price_id: 'price_test_solidarity_contribution',
        metadata: { 'sponsorship_contribution' => true }
      )
    end
    let(:beneficiary_community) { create(:better_together_community, name: 'Beneficiary Co-op', accepts_sponsorship: true) }

    it 'redirects to a hosted Stripe checkout session funding the beneficiary community, never the current community itself as owner' do
      checkout_session = instance_double(Stripe::Checkout::Session, url: 'https://checkout.stripe.test/contribution-session')
      Pay::Stripe::Customer.create!(owner: community, processor: 'stripe', processor_id: 'cus_sponsor_contribution')

      allow(Stripe::Checkout::Session).to receive(:create).and_return(checkout_session)

      post better_together.contribute_community_billing_path(community, locale:),
           params: { beneficiary_community_id: beneficiary_community.slug, billing_plan_id: contribution_plan.identifier }

      expect(response).to redirect_to('https://checkout.stripe.test/contribution-session')
      expect(Stripe::Checkout::Session).to have_received(:create).with(
        hash_including(
          customer: 'cus_sponsor_contribution',
          mode: 'payment',
          client_reference_id: community.id,
          metadata: hash_including(
            bt_sponsorship_beneficiary_type: 'BetterTogether::Community',
            bt_sponsorship_beneficiary_id: beneficiary_community.id
          )
        ),
        anything
      )
    end

    it 'redirects with an alert when the beneficiary community cannot be found' do
      post better_together.contribute_community_billing_path(community, locale:),
           params: { beneficiary_community_id: 'does-not-exist', billing_plan_id: contribution_plan.identifier }

      expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
      follow_redirect!
      expect(response.body).to include('That community or contribution amount is not available.')
    end

    it 'redirects with an alert when the billing plan is not a sponsorship contribution plan' do
      post better_together.contribute_community_billing_path(community, locale:),
           params: { beneficiary_community_id: beneficiary_community.slug, billing_plan_id: billing_plan.identifier }

      expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
    end

    it 'fails closed before any Stripe redirect when the beneficiary has not opted in to sponsorship' do
      opted_out_beneficiary = create(:better_together_community, name: 'Opted Out Co-op', accepts_sponsorship: false)

      allow(Stripe::Checkout::Session).to receive(:create)

      post better_together.contribute_community_billing_path(community, locale:),
           params: { beneficiary_community_id: opted_out_beneficiary.slug, billing_plan_id: contribution_plan.identifier }

      expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
      follow_redirect!
      expect(response.body).to include('This community has not opted in to receive sponsorship contributions.')
      expect(Stripe::Checkout::Session).not_to have_received(:create)
    end

    context 'when sponsorship consent is enforced' do
      around do |example|
        original = ENV.fetch('BT_BILLING_SPONSORSHIP_CONSENT_ENFORCED', nil)
        ENV['BT_BILLING_SPONSORSHIP_CONSENT_ENFORCED'] = 'true'
        example.run
      ensure
        ENV['BT_BILLING_SPONSORSHIP_CONSENT_ENFORCED'] = original
      end

      it 'rejects the contribution before any Stripe checkout session is created when the beneficiary has not opted in' do
        allow(Stripe::Checkout::Session).to receive(:create)

        post better_together.contribute_community_billing_path(community, locale:),
             params: { beneficiary_community_id: beneficiary_community.slug, billing_plan_id: contribution_plan.identifier }

        expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
        follow_redirect!
        expect(response.body).to include('This community has not opted in to receive sponsorship contributions.')
        expect(Stripe::Checkout::Session).not_to have_received(:create)
      end

      it 'allows the contribution once the beneficiary has opted in' do
        beneficiary_community.update!(accepts_sponsorship: true)
        checkout_session = instance_double(Stripe::Checkout::Session, url: 'https://checkout.stripe.test/consenting-session')
        Pay::Stripe::Customer.create!(owner: community, processor: 'stripe', processor_id: 'cus_sponsor_consenting')
        allow(Stripe::Checkout::Session).to receive(:create).and_return(checkout_session)

        post better_together.contribute_community_billing_path(community, locale:),
             params: { beneficiary_community_id: beneficiary_community.slug, billing_plan_id: contribution_plan.identifier }

        expect(response).to redirect_to('https://checkout.stripe.test/consenting-session')
      end
    end
  end

  describe 'GET /:locale/c/:community_id/billing (sponsorship contribution checkout return)' do
    let!(:contribution_plan) do
      create(
        :better_together_billing_plan,
        identifier: 'solidarity-contribution-return',
        billing_interval: 'one_time',
        amount_cents: 2_500,
        stripe_price_id: 'price_test_solidarity_contribution_return',
        metadata: { 'sponsorship_contribution' => true }
      )
    end
    let(:beneficiary_community) { create(:better_together_community, name: 'Funded Co-op', accepts_sponsorship: true) }
    let!(:sponsor_pay_customer) do
      Pay::Customer.create!(owner: community, processor: 'stripe', processor_id: 'cus_sponsor_return')
    end
    let!(:beneficiary_pay_customer) do
      Pay::Customer.create!(owner: beneficiary_community, processor: 'stripe', processor_id: 'cus_beneficiary_return', default: true)
    end

    let(:build_contribution_checkout_session) do
      lambda do |id:|
        price = Struct.new(:id, keyword_init: true).new(id: contribution_plan.stripe_price_id)
        line_item = Struct.new(:price, keyword_init: true).new(price:)
        line_items = Struct.new(:data, keyword_init: true).new(data: [line_item])
        payment_intent = Struct.new(:id, keyword_init: true).new(id: "pi_test_#{id}")

        Struct.new(
          :id, :customer, :subscription, :payment_intent, :amount_total, :currency, :metadata, :line_items,
          keyword_init: true
        ).new(
          id:,
          customer: sponsor_pay_customer.processor_id,
          subscription: nil,
          payment_intent:,
          amount_total: 2_500,
          currency: 'cad',
          metadata: {
            'bt_billing_plan_id' => contribution_plan.id,
            'bt_sponsorship_beneficiary_type' => 'BetterTogether::Community',
            'bt_sponsorship_beneficiary_id' => beneficiary_community.id
          },
          line_items:
        )
      end
    end

    it 'credits the beneficiary balance and records a MonetaryContribution when the checkout completes' do
      checkout_session = build_contribution_checkout_session.call(id: 'cs_test_contribution_return')
      balance_transaction = Struct.new(:id, keyword_init: true).new(id: 'txn_test_contribution_return')

      allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(checkout_session)
      allow(Stripe::Customer).to receive(:create_balance_transaction).and_return(balance_transaction)

      get better_together.community_billing_path(community, locale:, checkout_session_id: 'cs_test_contribution_return')

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Your contribution to Funded Co-op was recorded.')
      expect(
        BetterTogether::Billing::Sponsorship.status_active.for_sponsor(community).for_beneficiary(beneficiary_community)
      ).to exist
      expect(BetterTogether::Billing::MonetaryContribution.sole).to have_attributes(amount_cents: 2_500, currency: 'cad')
      expect(Stripe::Customer).to have_received(:create_balance_transaction).with(
        beneficiary_pay_customer.processor_id,
        hash_including(amount: -2_500)
      )
    end

    it 'never credits the beneficiary balance twice for the same checkout session, even revisited' do
      checkout_session = build_contribution_checkout_session.call(id: 'cs_test_contribution_repeat')
      balance_transaction = Struct.new(:id, keyword_init: true).new(id: 'txn_test_contribution_repeat')

      allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(checkout_session)
      allow(Stripe::Customer).to receive(:create_balance_transaction).and_return(balance_transaction)

      get better_together.community_billing_path(community, locale:, checkout_session_id: 'cs_test_contribution_repeat')
      get better_together.community_billing_path(community, locale:, checkout_session_id: 'cs_test_contribution_repeat')

      expect(BetterTogether::Billing::MonetaryContribution.count).to eq(1)
      expect(Stripe::Customer).to have_received(:create_balance_transaction).once
    end

    it 'allows a second, different sponsor to independently fund the same beneficiary without conflict' do
      other_sponsor = create(:better_together_community, name: 'Second Sponsor')
      other_sponsor_pay_customer = Pay::Customer.create!(owner: other_sponsor, processor: 'stripe', processor_id: 'cus_other_sponsor_return')
      first_session = build_contribution_checkout_session.call(id: 'cs_test_first_sponsor')
      second_session = build_contribution_checkout_session.call(id: 'cs_test_second_sponsor')
      second_session.customer = other_sponsor_pay_customer.processor_id
      first_balance_transaction = Struct.new(:id, keyword_init: true).new(id: 'txn_test_multi_sponsor_1')
      second_balance_transaction = Struct.new(:id, keyword_init: true).new(id: 'txn_test_multi_sponsor_2')

      allow(Stripe::Customer).to receive(:create_balance_transaction).and_return(
        first_balance_transaction, second_balance_transaction
      )

      allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(first_session)
      get better_together.community_billing_path(community, locale:, checkout_session_id: 'cs_test_first_sponsor')

      allow(Stripe::Checkout::Session).to receive(:retrieve).and_return(second_session)
      get better_together.community_billing_path(other_sponsor, locale:, checkout_session_id: 'cs_test_second_sponsor')

      expect(BetterTogether::Billing::Sponsorship.status_active.for_beneficiary(beneficiary_community).count).to eq(2)
      expect(BetterTogether::Billing::MonetaryContribution.count).to eq(2)
    end
  end

  describe 'POST /:locale/c/:community_id/billing/portal' do
    it 'redirects to the Stripe billing portal' do
      portal_session = instance_double(Stripe::BillingPortal::Session, url: 'https://billing.stripe.test/session')
      Pay::Stripe::Customer.create!(owner: community, processor: 'stripe', processor_id: 'cus_community_portal')

      allow(Stripe::BillingPortal::Session).to receive(:create).and_return(portal_session)

      post better_together.portal_community_billing_path(community, locale:)

      expect(response).to redirect_to('https://billing.stripe.test/session')
    end

    it 'is unaffected by a subscription owned by a different party — no more cross-owner discovery' do
      other_owner = create(:better_together_person)
      create(:better_together_billing_subscription, billable_owner: other_owner, billing_plan:)
      portal_session = instance_double(Stripe::BillingPortal::Session, url: 'https://billing.stripe.test/isolated')
      Pay::Stripe::Customer.create!(owner: community, processor: 'stripe', processor_id: 'cus_community_isolated')
      allow(Stripe::BillingPortal::Session).to receive(:create).and_return(portal_session)

      post better_together.portal_community_billing_path(community, locale:)

      expect(response).to redirect_to('https://billing.stripe.test/isolated')
      expect(Stripe::BillingPortal::Session).to have_received(:create).with(
        hash_including(
          customer: 'cus_community_isolated',
          return_url: better_together.community_billing_url(community, locale:)
        ),
        anything
      )
    end

    it 'persists portal failure support state on the billing subscription' do
      billing_subscription = create(
        :better_together_billing_subscription,
        billable_owner: community,
        beneficiary: community,
        billing_plan:
      )

      Pay::Stripe::Customer.create!(owner: community, processor: 'stripe', processor_id: 'cus_community_portal_failure')
      allow(Stripe::BillingPortal::Session).to receive(:create).and_raise(StandardError, 'Stripe portal outage')

      post better_together.portal_community_billing_path(community, locale:)

      expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
      expect(billing_subscription.reload.last_portal_error_message).to eq('Stripe portal outage')

      get better_together.community_billing_path(community, locale:)
      expect(response.body).to include(
        I18n.t('better_together.billing.portal_access_attention', default: 'Billing portal access needs attention.')
      )
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

    it 'only queues reconciliation for the community itself, even when other subscriptions exist elsewhere' do
      friendly_scope = instance_double(ActiveRecord::Relation, find: community)
      other_owner = create(:better_together_person)
      create(:better_together_billing_subscription, billable_owner: other_owner, billing_plan:)

      allow(BetterTogether::Community).to receive(:friendly).and_return(friendly_scope)

      post better_together.reconcile_community_billing_path(community, locale:)

      reconciliation_jobs = enqueued_jobs.filter_map do |job|
        next unless job[:job] == BetterTogether::Billing::ReconcileStripeBillableOwnerBillingJob

        job[:args]
      end

      expect(reconciliation_jobs).to eq([[community.class.name, community.id]])
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
      expect(service).to have_received(:call).with(merchant_account:, owner: community)
    end
  end

  describe 'GET /:locale/c/:community_id/billing/provision_platform' do
    context 'when the community has an active hosted subscription' do
      it 'creates a draft platform linked to the community and redirects into the setup wizard' do
        create_owned_billing_subscription(owner: community, billing_plan:, status: 'active')

        expect do
          get better_together.provision_platform_community_billing_path(community, locale:)
        end.to change(BetterTogether::Platform, :count).by(1)

        draft = BetterTogether::Platform.order(:created_at).last
        expect(draft.provisioning_community).to eq(community)
        expect(response).to redirect_to(
          better_together.new_platform_setup_step_welcome_path(platform_id: draft.to_param)
        )
      end

      it 'builds the wizard for the draft platform' do
        create_owned_billing_subscription(owner: community, billing_plan:, status: 'active')

        get better_together.provision_platform_community_billing_path(community, locale:)

        draft = BetterTogether::Platform.order(:created_at).last
        expect(BetterTogether::Wizard.for_platform(draft)
          .find_by(identifier: BetterTogether::NewPlatformSetupWizardBuilder::IDENTIFIER)).to be_present
      end
    end

    it 'does not create a platform and redirects with an alert when subscription is past_due' do
      create_owned_billing_subscription(owner: community, billing_plan:, status: 'past_due')

      expect do
        get better_together.provision_platform_community_billing_path(community, locale:)
      end.not_to change(BetterTogether::Platform, :count)

      expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
      expect(flash[:alert]).to include('active hosted plan is required')
    end

    it 'does not create a platform and redirects with an alert when there is no active subscription' do
      expect do
        get better_together.provision_platform_community_billing_path(community, locale:)
      end.not_to change(BetterTogether::Platform, :count)

      expect(response).to redirect_to(better_together.community_billing_path(community, locale:))
      expect(flash[:alert]).to include('active hosted plan is required')
    end
  end
end
