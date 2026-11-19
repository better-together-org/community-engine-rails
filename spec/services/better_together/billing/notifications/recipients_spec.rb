# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Notifications::Recipients do
  include_context 'with billing notifications'

  let(:order) { place_order }

  def recipients(audience, subject = order, **attrs) = described_class.call(audience:, subject:, **attrs)

  before { steward && other_steward }

  it 'means the buyer for the buyer audience, whether the subject is the order, its payment or its refund' do
    payment = create(:better_together_billing_payment, order:, status: 'succeeded', amount_cents: 4500)
    refund = create(:better_together_billing_refund, payment:, amount_cents: 100)

    [order, payment, refund].each { |subject| expect(recipients(:buyer, subject)).to eq([buyer]) }
  end

  it 'means the platform\'s billing managers for sellers and operators' do
    expect(recipients(:seller)).to include(steward, other_steward)
    expect(recipients(:operator)).to include(steward, other_steward)
    expect(recipients(:seller)).not_to include(buyer)
  end

  it 'leaves out the person who just did it' do
    expect(recipients(:seller, actor: steward)).to include(other_steward)
    expect(recipients(:seller, actor: steward)).not_to include(steward)
    expect(recipients(:buyer, actor: buyer)).to be_empty
  end

  it 'never tells a steward of another platform' do
    other = create(:better_together_platform)
    foreign_order = create(:better_together_billing_order, platform: other)
    foreign_manager = create(:better_together_person)
    role = BetterTogether::Role.joins(:resource_permissions).find_by(better_together_resource_permissions: { identifier: 'manage_platform' })
    BetterTogether::PersonPlatformMembership.create!(member: foreign_manager, joinable: other, role:, status: 'active')

    expect(recipients(:seller, foreign_order)).to eq([foreign_manager])
    expect(recipients(:seller)).not_to include(foreign_manager)
  end

  it 'has nobody to tell at the platform when a community sold the order' do
    BetterTogether::Billing::Billable.model_names << 'BetterTogether::Community'
    sold = create(:better_together_billing_order, seller: create(:better_together_community))

    expect(recipients(:seller, sold)).to be_empty
  end

  it 'has nobody for an audience it does not know, and each person once' do
    expect(recipients(:nobody)).to be_empty
    expect(recipients(:seller).map(&:id)).to eq(recipients(:seller).map(&:id).uniq)
  end

  it 'finds the managers of a record that is not an order, by its platform' do
    setting = host_platform.billing_processor_settings.build(processor: 'cash')

    expect(recipients(:operator, setting)).to include(steward)
  end
end
