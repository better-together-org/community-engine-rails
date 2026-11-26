# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Billing demo seed packet' do # rubocop:disable RSpec/DescribeClass
  include_context 'with builtin billing processors'

  let(:platform) { configure_host_platform }
  let(:path) { BetterTogether::Engine.root.join('config/seeds/better_together/billing_demo') }

  def plant(apply:) = BetterTogether::Seeds::Plant.call(path: path.to_s, platform:, apply:)

  it 'plans with no errors and writes nothing', :aggregate_failures do
    report = plant(apply: false)

    expect(report[:errors]).to be_empty
    expect { plant(apply: false) }.not_to change(BetterTogether::Billing::Plan, :count)
  end

  it 'plants the demo catalog once, and again changes nothing', :aggregate_failures do
    first = plant(apply: true)
    second = plant(apply: true)

    expect(first[:errors]).to be_empty
    expect(BetterTogether::Billing::Plan.where(platform:).count).to eq(4)
    expect(second).to include(created: 0, updated: 0, unchanged: 13)
  end

  it 'plants the extra storage as a product that needs a supporter plan, and the paid plans carrying a storage allowance', :aggregate_failures do
    plant(apply: true)
    extra = BetterTogether::Billing::Product.find_by!(platform:, identifier: 'demo-extra-storage')
    monthly = BetterTogether::Billing::Plan.find_by!(platform:, identifier: 'demo-supporter-monthly')

    expect(extra.prices.sole).to have_attributes(amount_cents: 300, currency: 'CAD')
    expect(BetterTogether::Billing::PurchaseRequirement.for_dependent(extra).map(&:prerequisite)).to include(monthly)
    expect(monthly.grants.map(&:kind)).to eq(['quota_allowance'])
  end

  it 'plants the storage top-up as a fixed-term product with a price and a storage grant', :aggregate_failures do
    plant(apply: true)
    product = BetterTogether::Billing::Product.find_by!(platform:, identifier: 'demo-storage-top-up')

    expect(product).to have_attributes(lifetime: 'fixed_term', term_length: 12, term_unit: 'month', name: '[Demo] Storage top-up')
    expect(product.prices.sole).to have_attributes(amount_cents: 500, currency: 'CAD', platform_id: platform.id)
    expect(product.grants.sole).to have_attributes(kind: 'quota_allowance', platform_id: platform.id)
  end
end
