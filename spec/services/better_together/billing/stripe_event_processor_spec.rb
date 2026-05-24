# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::StripeEventProcessor do
  describe '#call' do
    let(:community) { create(:better_together_community) }
    let!(:billing_plan) do
      create(
        :better_together_billing_plan,
        identifier: 'community-ops',
        stripe_price_id: 'price_community_ops'
      )
    end
    let!(:pay_customer) do
      Pay::Customer.create!(
        owner: community,
        processor: 'stripe',
        processor_id: 'cus_test_123'
      )
    end
    let!(:pay_subscription) do
      Pay::Subscription.create!(
        customer: pay_customer,
        name: 'default',
        processor_id: 'sub_test_123',
        processor_plan: billing_plan.stripe_price_id,
        status: 'active',
        current_period_start: Time.current.beginning_of_day,
        current_period_end: 1.month.from_now.beginning_of_day
      )
    end
    let(:subscription_object) do
      price = Struct.new(:id, keyword_init: true).new(id: billing_plan.stripe_price_id)
      line_item = Struct.new(:price, keyword_init: true).new(price:)
      items = Struct.new(:data, keyword_init: true).new(data: [line_item])

      Struct.new(
        :id,
        :customer,
        :status,
        :current_period_start,
        :current_period_end,
        :cancel_at_period_end,
        :metadata,
        :items,
        keyword_init: true
      ).new(
        id: 'sub_test_123',
        customer: pay_customer.processor_id,
        status: 'active',
        current_period_start: 1_777_777_777,
        current_period_end: 1_780_000_000,
        cancel_at_period_end: false,
        metadata: { 'bt_billing_plan_id' => billing_plan.id, 'bt_community_id' => community.id },
        items:
      )
    end
    let(:event) do
      data = Struct.new(:object, keyword_init: true).new(object: subscription_object)
      payload = { id: 'evt_test_123', type: 'customer.subscription.created' }

      Struct.new(:id, :type, :data, :payload, keyword_init: true) do
        def to_hash
          payload
        end
      end.new(id: 'evt_test_123', type: 'customer.subscription.created', data:, payload:)
    end

    it 'logs the event and syncs a local BTS billing subscription' do
      described_class.new.call(event)

      billing_event = BetterTogether::Billing::Event.find_by!(processor: 'stripe', event_id: event.id)
      billing_subscription = Pay::Subscription.stripe
                                              .find_by!(processor_id: 'sub_test_123')
                                              .billing_subscription_record

      expect(billing_event.processing_status).to eq('processed')
      expect(billing_event.billable_owner).to eq(community)
      expect(billing_event.beneficiary).to eq(community)
      expect(billing_subscription.pay_subscription.customer.owner).to eq(community)
      expect(billing_subscription.billing_plan).to eq(billing_plan)
      expect(billing_subscription.status).to eq('active')
    end

    it 'syncs merchant account updates into the local merchant account' do
      merchant_account = create(
        'better_together/billing/merchant_account',
        owner: community,
        provider: 'stripe_connect',
        external_account_id: 'acct_connect_123',
        status: 'pending',
        charges_enabled: false,
        payouts_enabled: false
      )
      merchant_event = Struct.new(:id, :type, :data, :payload, :account, keyword_init: true) do
        def to_hash
          payload
        end
      end.new(
        id: 'evt_acct_123',
        type: 'account.updated',
        data: Struct.new(:object, keyword_init: true).new(object: instance_double(
          Stripe::Account,
          id: 'acct_connect_123',
          country: 'CA',
          default_currency: 'cad',
          charges_enabled: true,
          payouts_enabled: true,
          details_submitted: true,
          business_type: 'company',
          capabilities: { transfers: 'active', card_payments: 'active' },
          requirements: double(
            currently_due: [],
            eventually_due: [],
            past_due: [],
            pending_verification: [],
            disabled_reason: nil
          )
        )),
        payload: { id: 'evt_acct_123', type: 'account.updated' },
        account: nil
      )

      described_class.new.call(merchant_event)

      billing_event = BetterTogether::Billing::Event.find_by!(processor: 'stripe', event_id: merchant_event.id)

      expect(merchant_account.reload.status).to eq('active')
      expect(merchant_account.charges_enabled).to be(true)
      expect(merchant_account.payouts_enabled).to be(true)
      expect(billing_event.processing_status).to eq('processed')
      expect(billing_event.billable_owner).to eq(community)
    end

    it 'marks merchant accounts disconnected when Stripe deauthorizes access' do
      merchant_account = create(
        'better_together/billing/merchant_account',
        owner: community,
        provider: 'stripe_connect',
        external_account_id: 'acct_connect_456',
        status: 'active',
        charges_enabled: true,
        payouts_enabled: true
      )
      merchant_event = Struct.new(:id, :type, :data, :payload, :account, keyword_init: true) do
        def to_hash
          payload
        end
      end.new(
        id: 'evt_acct_deauth_123',
        type: 'account.application.deauthorized',
        data: Struct.new(:object, keyword_init: true).new(object: Struct.new(:id, keyword_init: true).new(id: nil)),
        payload: { id: 'evt_acct_deauth_123', type: 'account.application.deauthorized' },
        account: 'acct_connect_456'
      )

      described_class.new.call(merchant_event)

      billing_event = BetterTogether::Billing::Event.find_by!(processor: 'stripe', event_id: merchant_event.id)

      expect(merchant_account.reload.status).to eq('disconnected')
      expect(merchant_account.charges_enabled).to be(false)
      expect(merchant_account.payouts_enabled).to be(false)
      expect(billing_event.processing_status).to eq('processed')
      expect(billing_event.billable_owner).to eq(community)
    end

    it 'routes price.updated events to StripePriceSync' do
      price_sync_service = instance_double(BetterTogether::Billing::StripePriceSync)
      allow(BetterTogether::Billing::StripePriceSync).to receive(:new).and_return(price_sync_service)
      allow(price_sync_service).to receive(:call).and_return(
        BetterTogether::Billing::StripePriceSync::Result.new(
          synced: true,
          plan: billing_plan,
          reason: :synced
        )
      )

      price_object = Struct.new(:id, :active, keyword_init: true).new(
        id: billing_plan.stripe_price_id,
        active: false
      )
      data = Struct.new(:object, keyword_init: true).new(object: price_object)
      price_event = Struct.new(:id, :type, :data, :payload, keyword_init: true) do
        def to_hash
          payload
        end
      end.new(
        id: 'evt_price_upd_proc',
        type: 'price.updated',
        data: data,
        payload: { id: 'evt_price_upd_proc', type: 'price.updated' }
      )

      described_class.new.call(price_event)

      expect(price_sync_service).to have_received(:call).with(event: price_event)
      expect(BetterTogether::Billing::Event.find_by!(processor: 'stripe', event_id: 'evt_price_upd_proc').processing_status)
        .to eq('processed')
    end

    it 'routes product.updated events to StripePriceSync' do
      price_sync_service = instance_double(BetterTogether::Billing::StripePriceSync)
      allow(BetterTogether::Billing::StripePriceSync).to receive(:new).and_return(price_sync_service)
      allow(price_sync_service).to receive(:call).and_return(
        BetterTogether::Billing::StripePriceSync::Result.new(
          synced: true,
          plan: billing_plan,
          reason: :synced
        )
      )

      billing_plan.update_columns(stripe_product_id: 'prod_proc_test')
      product_object = Struct.new(:id, :active, keyword_init: true).new(
        id: 'prod_proc_test',
        active: false
      )
      data = Struct.new(:object, keyword_init: true).new(object: product_object)
      product_event = Struct.new(:id, :type, :data, :payload, keyword_init: true) do
        def to_hash
          payload
        end
      end.new(
        id: 'evt_prod_upd_proc',
        type: 'product.updated',
        data: data,
        payload: { id: 'evt_prod_upd_proc', type: 'product.updated' }
      )

      described_class.new.call(product_event)

      expect(price_sync_service).to have_received(:call).with(event: product_event)
      expect(BetterTogether::Billing::Event.find_by!(processor: 'stripe', event_id: 'evt_prod_upd_proc').processing_status)
        .to eq('processed')
    end

    it 'persists invoice payment failures as billing alerts linked to the local subscription' do
      create(
        :better_together_billing_subscription,
        pay_subscription:,
        billing_plan:
      )
      invoice_object = Struct.new(
        :id,
        :object,
        :subscription,
        :customer,
        :status,
        :metadata,
        :last_payment_error,
        keyword_init: true
      ).new(
        id: 'in_test_123',
        object: 'invoice',
        subscription: 'sub_test_123',
        customer: pay_customer.processor_id,
        status: 'open',
        metadata: {},
        last_payment_error: Struct.new(:message, keyword_init: true).new(message: 'Card was declined.')
      )
      invoice_event = Struct.new(:id, :type, :data, :payload, keyword_init: true) do
        def to_hash
          payload
        end
      end.new(
        id: 'evt_invoice_failed_123',
        type: 'invoice.payment_failed',
        data: Struct.new(:object, keyword_init: true).new(object: invoice_object),
        payload: { id: 'evt_invoice_failed_123', type: 'invoice.payment_failed' }
      )

      described_class.new.call(invoice_event)

      billing_event = BetterTogether::Billing::Event.find_by!(processor: 'stripe', event_id: invoice_event.id)
      billing_subscription = Pay::Subscription.stripe
                                              .find_by!(processor_id: 'sub_test_123')
                                              .billing_subscription_record

      expect(billing_event.processing_status).to eq('failed')
      expect(billing_event.error_message).to include('Card was declined.')
      expect(billing_event.billing_subscription).to eq(billing_subscription)
      expect(billing_event.billable_owner).to eq(community)
      expect(billing_subscription.sync_source).to eq('stripe_financial_event')
      expect(billing_subscription.latest_processor_event_id).to eq('evt_invoice_failed_123')
    end
  end
end
