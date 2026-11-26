# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::RefundRequest do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }

  def build_request(**attrs)
    described_class.new({ order:, platform_id: order.platform_id, requester: buyer, currency: order.currency, reason: 'other' }.merge(attrs))
  end

  before do
    transition.receive(offline, by: steward)
    order.reload
  end

  it 'is valid for the buyer of a paid order' do
    expect(build_request).to be_valid
  end

  it 'is not valid for someone else' do
    expect(build_request(requester: steward)).not_to be_valid
  end

  it 'asks for no more than can be given back' do
    request = build_request(amount_cents: 999_999)

    expect(request).not_to be_valid
    expect(request.errors.details[:amount_cents].pluck(:error)).to include(:greater_than_refundable)
  end

  it 'is not valid when the order has nothing to give back here' do
    unpaid = place_offline('cash')

    expect(build_request(order: unpaid, platform_id: unpaid.platform_id)).not_to be_valid
  end

  it 'allows one waiting request per order' do
    build_request.save!

    expect(build_request).not_to be_valid
  end

  it 'keeps what was written encrypted at rest' do
    request = build_request(details: 'my private reason')
    request.save!

    raw = described_class.connection.select_value("SELECT details FROM #{described_class.table_name} WHERE id = '#{request.id}'")
    expect(raw).not_to include('my private reason')
    expect(request.reload.details).to eq('my private reason')
  end
end
