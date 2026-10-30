# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ExpireOrdersJob do
  include_context 'with orders fixtures'

  it 'runs on the billing queue' do
    expect(described_class.new.queue_name).to eq(BetterTogether::Billing::ApplicationJob.new.queue_name)
  end

  it 'lets orders whose hold ran out lapse, and leaves the rest' do
    lapsed = place_order.tap { |order| order.update!(expires_at: 1.hour.ago) }
    current = place_order
    paid = place_order.tap { |order| order.update!(status: 'paid', expires_at: 1.hour.ago) }

    described_class.perform_now

    expect(lapsed.reload).to be_expired
    expect(current.reload).to be_awaiting_payment
    expect(paid.reload).to be_paid
  end

  it 'covers every platform, one order at a time' do
    other = create(:better_together_platform)
    other_order = create(:better_together_billing_order, :awaiting_payment, platform: other, expires_at: 1.hour.ago)

    described_class.perform_now

    expect(other_order.reload).to be_expired
  end

  it 'carries on past an order that cannot be expired' do
    bad = place_order.tap { |order| order.update!(expires_at: 2.hours.ago) }
    good = place_order.tap { |order| order.update!(expires_at: 1.hour.ago) }
    allow(BetterTogether::Billing::Orders::Expire).to receive(:call).and_call_original
    allow(BetterTogether::Billing::Orders::Expire).to receive(:call).with(satisfy { |order|
      order.id == bad.id
    }).and_raise(StandardError, 'boom')

    expect { described_class.perform_now }.not_to raise_error
    expect(good.reload).to be_expired
  end

  it 'is scheduled hourly without a queue key, so the job class chooses its prefixed queue' do
    entry = YAML.load_file(BetterTogether::Engine.root.join('config/sidekiq_scheduler.yml')).fetch('better_together:billing:expire_orders_hourly')

    expect(entry).to include('class' => 'BetterTogether::Billing::ExpireOrdersJob', 'cron' => '10 * * * *')
    expect(entry).not_to have_key('queue')
  end
end
