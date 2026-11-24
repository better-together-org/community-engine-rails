# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Billing demo seed packet' do # rubocop:disable RSpec/DescribeClass
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
    expect(BetterTogether::Billing::Plan.where(platform:).count).to eq(5)
    expect(second).to include(created: 0, updated: 0, unchanged: 9)
  end

  it 'keeps the add-on a one-time extra and the paid plans carrying a storage allowance', :aggregate_failures do
    plant(apply: true)
    add_on = BetterTogether::Billing::Plan.find_by!(platform:, identifier: 'demo-extra-storage')
    monthly = BetterTogether::Billing::Plan.find_by!(platform:, identifier: 'demo-supporter-monthly')

    expect(add_on).to have_attributes(add_on: true, billing_interval: 'one_time')
    expect(monthly.plan_grants.map(&:kind)).to eq(['quota_allowance'])
    expect(monthly.target_links.count + monthly.add_on_links.count).to eq(1)
  end
end
