# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Orders::Place do
  include_context 'with orders fixtures'

  def draft_agreements = BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform)

  it 'places an order waiting for payment, with a snapshot of what it holds' do
    order = place_order

    expect(order).to have_attributes(status: 'awaiting_payment', purpose: 'one_time', currency: 'USD', total_cents: 4500,
                                     subtotal_cents: 4500, buyer:, platform: host_platform)
    expect(order.number).to match(/\ABT-/)
    expect(order.placed_at).to be_present
    expect(order.expires_at).to be_within(1.minute).of(72.hours.from_now)
    expect(order.lines.first).to have_attributes(purchasable: plan, description: plan.name, quantity: 1, unit_amount_cents: 4500)
  end

  it 'holds the order for as long as it is told to' do
    expect(place_order(hold_hours: 24).expires_at).to be_within(1.minute).of(24.hours.from_now)
  end

  it 'multiplies quantity and adds up several lines' do
    other = create(:better_together_billing_plan, amount_cents: 1000, currency: 'USD')

    order = place_order(lines: [{ purchasable: plan, quantity: 2 }, { purchasable: other }])

    expect(order.total_cents).to eq((2 * 4500) + 1000)
    expect(order.lines.map(&:position)).to eq([0, 1])
  end

  it 'holds each purchasable it sells' do
    allow(plan).to receive(:reserve!)

    place_order(lines: [{ purchasable: plan, quantity: 3 }])

    expect(plan).to have_received(:reserve!).with(quantity: 3)
  end

  it 'rolls everything back, leaving nothing behind, when a purchasable refuses to be held' do
    allow(plan).to receive(:reserve!).and_raise(StandardError, 'sold out')

    expect { place_order }.to raise_error(described_class::Refused, 'sold out')
    expect(host_platform.billing_orders.reload).to be_empty
  end

  it 'settles an order that costs nothing straight away' do
    free = create(:better_together_billing_plan, amount_cents: 0, currency: 'USD')

    expect(place_order(lines: [{ purchasable: free }])).to be_paid
  end

  describe 'what it refuses' do
    it 'an order with no lines' do
      expect { place_order(lines: []) }.to raise_error(described_class::Refused, /at least one line/)
    end

    it 'something that cannot be bought' do
      expect { place_order(lines: [{ purchasable: buyer }]) }.to raise_error(described_class::Refused, /cannot be bought/)
    end

    it 'a plan that is not for sale' do
      plan.update!(active: false)

      expect { place_order }.to raise_error(described_class::Refused, /not for sale/)
    end

    it 'a purchasable of another platform' do
      other_platform = create(:better_together_platform)

      expect { place_order(agreements: false, platform: other_platform) }.to raise_error(described_class::Refused, /another platform/)
    end

    it 'a purchasable sold by someone else' do
      BetterTogether::Billing::Billable.model_names << 'BetterTogether::Community'
      community = create(:better_together_community)
      seller_plan = create(:better_together_billing_plan, seller: community)

      expect { place_order(lines: [{ purchasable: seller_plan }]) }.to raise_error(described_class::Refused, /sold by someone else/)
      expect(place_order(lines: [{ purchasable: seller_plan }], seller: community).seller).to eq(community)
    end

    it 'a plan sold by the platform when a seller is named' do
      BetterTogether::Billing::Billable.model_names << 'BetterTogether::Community'

      expect { place_order(seller: create(:better_together_community)) }.to raise_error(described_class::Refused, /sold by someone else/)
    end

    it 'lines in different currencies' do
      cad = create(:better_together_billing_plan, currency: 'CAD')

      expect { place_order(lines: [{ purchasable: plan }, { purchasable: cad }]) }.to raise_error(described_class::Refused, /same currency/)
    end

    it 'a purpose that is not known' do
      expect { place_order(agreements: false, purpose: 'barter') }.to raise_error(described_class::Refused, /not a kind of purchase/)
    end
  end

  describe 'the purchase agreements' do
    it 'refuses while they are only drafts, however the screens behaved' do
      draft_agreements

      expect { place_order(agreements: false) }.to raise_error(described_class::AgreementsRequired) { |error|
        expect(error.gate.problems.map(&:code)).to eq([:not_in_force])
      }
      expect(host_platform.billing_orders.reload).to be_empty
    end

    it 'refuses when the buyer has not accepted them' do
      draft_agreements.each_value { |agreement| agreement.update!(lifecycle_state: 'active') }

      expect { place_order(agreements: false) }.to raise_error(described_class::AgreementsRequired) { |error|
        expect(error.gate.missing.map(&:identifier)).to eq(['one_time_purchase_agreement'])
      }
    end

    it 'refuses when the platform requires no agreement at all (fail closed)' do
      host_platform.billing_agreement_requirements.destroy_all

      expect { place_order(agreements: false) }.to raise_error(described_class::AgreementsRequired)
    end

    it 'refuses a zero-total order too, since it is still a purchase' do
      free = create(:better_together_billing_plan, amount_cents: 0, currency: 'USD')

      expect { place_order(agreements: false, lines: [{ purchasable: free }]) }.to raise_error(described_class::AgreementsRequired)
    end

    it 'copies the buyer\'s acceptance onto the order as its evidence' do
      order = place_order

      expect(order.agreement_acceptances.map(&:agreement_identifier)).to eq(['one_time_purchase_agreement'])
      expect(order.agreement_acceptances.first).to have_attributes(signer: buyer, platform_id: host_platform.id)
    end

    it 'checks the signer, who may be someone other than the buyer, and copies theirs' do
      signer = create(:better_together_person)

      order = place_order(signer:)

      expect(order.agreement_acceptances.first.signer).to eq(signer)
      expect(order.buyer).to eq(buyer)
    end

    it 'asks for the payment method\'s own terms too' do
      BetterTogether::Billing.register_builtin_processors!
      purchase_agreements_for(host_platform)

      expect { place_order(agreements: false, payment_method: 'cash') }.to raise_error(described_class::AgreementsRequired)
      order = place_order(payment_method: 'cash')
      expect(order.agreement_acceptances.map(&:agreement_identifier)).to contain_exactly('one_time_purchase_agreement', 'offline_payment_terms')
    end
  end
end
