# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::HostedAccessGraceNotifier do
  subject(:notifier) { described_class.new(record: subscription, params: { subscription: subscription }) }

  let(:community) { create(:better_together_community) }
  let(:manager) { create(:better_together_person) }
  let(:pay_customer) { create('pay/customer', owner: community) }
  let(:pay_subscription) { create('pay/subscription', customer: pay_customer, status: 'canceled') }
  let(:subscription) { create('better_together/billing/subscription', pay_subscription:) }
  let(:notification) { instance_double(Noticed::Notification, recipient: manager) }

  around do |example|
    original = ENV.fetch('BT_BILLING_HOSTED_ACCESS_GRACE_PERIOD_DAYS', nil)
    ENV['BT_BILLING_HOSTED_ACCESS_GRACE_PERIOD_DAYS'] = '7'
    subscription.sync_lapse_state!
    example.run
  ensure
    ENV['BT_BILLING_HOSTED_ACCESS_GRACE_PERIOD_DAYS'] = original
  end

  describe '#title' do
    it 'includes the community name without raising' do
      expect { notifier.title }.not_to raise_error
      expect(notifier.title).to include(community.name)
    end
  end

  describe '#body' do
    it 'includes the grace period expiry date without raising' do
      expect { notifier.body }.not_to raise_error
      expect(notifier.body).to include(subscription.grace_period_expires_at.to_date.to_s)
    end
  end

  describe '#build_message' do
    it 'returns a hash with title, body, and a billing url' do
      message = notifier.build_message(notification)

      expect(message).to include(:title, :body, :url)
      expect(message[:url]).to include(community.to_param)
    end
  end

  describe '#email_params' do
    it 'uses notification.recipient instead of a bare recipient call' do
      params = notifier.email_params(notification)

      expect(params[:recipient]).to eq(manager)
      expect(params[:subscription]).to eq(subscription)
      expect(params[:billing_url]).to include(community.to_param)
    end
  end
end
