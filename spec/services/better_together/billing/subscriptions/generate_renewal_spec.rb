# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Subscriptions::GenerateRenewal do
  include_context 'with subscription fixtures'

  let(:term) { start_subscription }
  let(:inside_lead) { Time.utc(2027, 2, 20, 8) } # period ends Feb 28; 14 days ahead opens Feb 14
  let(:before_lead) { Time.utc(2027, 2, 10, 8) }

  it 'does nothing before the plan\'s lead time' do
    expect(generate_renewal(term, at: before_lead)).to be_nil
    expect(term.periods.count).to eq(1)
  end

  it 'makes the next period and its invoice inside the lead time' do
    period = generate_renewal(term, at: inside_lead)

    expect(period).to have_attributes(sequence: 1, status: 'pending', starts_at: Time.utc(2027, 2, 28, 15), ends_at: Time.utc(2027, 3, 31, 15))
    expect(period.order).to have_attributes(status: 'awaiting_payment', subject: term, buyer: buyer, total_cents: 3000, purpose: 'subscription')
    expect(period.order.offline_payments.sole).to have_attributes(processor: 'cash', status: 'awaiting')
  end

  it 'taxes the invoice for the place the subscriber was taxed for, with the rates in force now', :aggregate_failures do
    create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA')
    zone = create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA', region_code: 'NL')
    create(:better_together_billing_tax_rate, platform: host_platform, tax_zone: zone, label: 'HST', rate: 0.15)
    term
    BetterTogether::Billing::Order.update_all(tax_country_iso: 'CA', tax_region_code: 'NL') # rubocop:disable Rails/SkipsModelValidations

    order = generate_renewal(term, at: inside_lead).order

    expect(order).to have_attributes(subtotal_cents: 3000, tax_cents: 450, total_cents: 3450, tax_country_iso: 'CA', tax_region_code: 'NL')
    expect(order.tax_lines.map(&:label)).to eq(['HST'])
  end

  it 'holds the invoice until the period ends plus the plan\'s grace, so a late payment still lands' do
    period = generate_renewal(term, at: inside_lead)

    expect(period.order.expires_at).to be_within(1.second).of(Time.utc(2027, 3, 31, 15) + 7.days)
  end

  it 'invoices the price the subscriber was sold at, not the plan\'s price today' do
    term
    sub_plan.update_columns(amount_cents: 5000) # rubocop:disable Rails/SkipsModelValidations

    expect(generate_renewal(term, at: inside_lead).order.total_cents).to eq(3000)
  end

  it 'makes one invoice however often it runs' do
    first = generate_renewal(term, at: inside_lead)

    expect { generate_renewal(term, at: inside_lead + 1.day) }.not_to change(BetterTogether::Billing::Order, :count)
    expect(term.periods.count).to eq(2)
    expect(term.periods.last).to eq(first)
  end

  it 'tells the payer about the invoice' do
    clear_notices
    deliver_now { generate_renewal(term, at: inside_lead) }

    expect(kinds_for(buyer)).to include('renewal_invoice_issued')
  end

  it 'does not invoice a subscription that is ending or has ended' do
    term.pay_subscription.cancel

    expect(generate_renewal(term, at: inside_lead)).to be_nil
  end

  context 'when the purchase agreements changed since the payer accepted them' do
    before do
      term
      change_subscription_agreement
    end

    it 'waits as needs_agreement and tells the payer, instead of invoicing' do
      clear_notices
      period = nil
      deliver_now { period = generate_renewal(term, at: inside_lead) }

      expect(period).to have_attributes(status: 'needs_agreement', order: nil)
      expect(kinds_for(buyer)).to include('agreement_reacceptance_needed')
    end

    it 'invoices on the next run once they are accepted' do
      generate_renewal(term, at: inside_lead)
      gate = BetterTogether::Billing::Checkout::AgreementGate.new(platform: host_platform, purpose: 'subscription', signer: buyer,
                                                                  purchasables: [sub_plan], payment_method: 'cash')
      gate.accept!

      period = generate_renewal(term, at: inside_lead + 1.day)

      expect(period).to have_attributes(status: 'pending')
      expect(period.order).to be_present
    end
  end

  it 'is blocked, with a reason, when the payment method was switched off, and tries again later' do
    term
    host_platform.billing_processor_settings.find_by!(processor: 'cash').update!(enabled: false)

    period = generate_renewal(term, at: inside_lead)
    expect(period).to have_attributes(status: 'blocked', order: nil)
    expect(period.blocked_reason).to be_present

    host_platform.billing_processor_settings.find_by!(processor: 'cash').update!(enabled: true)
    expect(generate_renewal(term, at: inside_lead + 1.day)).to have_attributes(status: 'pending')
  end

  it 'still renews a plan that is no longer for sale' do
    term
    sub_plan.update_columns(active: false) # rubocop:disable Rails/SkipsModelValidations

    expect(generate_renewal(term, at: inside_lead).order).to be_present
  end

  context 'with store credit' do
    let(:term) { start_subscription(method: 'store_credit') }

    it 'pays the invoice from credit at once when it covers it, and the subscription moves on' do
      give_credit(3000)
      nil
      period = follow_up { generate_renewal(term, at: inside_lead) }

      expect(period.reload.order).to be_paid
      expect(period).to be_paid
      expect(term.reload.pay_subscription.current_period_end).to eq(Time.utc(2027, 3, 31, 15))
    end

    it 'leaves the invoice waiting and tells the payer when credit does not cover it, then tries again when topped up' do
      clear_notices
      period = nil
      deliver_now { period = generate_renewal(term, at: inside_lead) }
      expect(period.order).to be_open
      expect(kinds_for(buyer)).to include('renewal_credit_insufficient')

      give_credit(3000)
      travel_to(inside_lead + 1.day) { follow_up { BetterTogether::Billing::Subscriptions::PayWithCredit.call(period: period.reload) } }

      expect(period.reload.order).to be_paid
    end
  end
end
