# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::NotifyHostedAccessGraceJob do
  let(:community) { create(:better_together_community) }
  let(:community_manager_role) do
    BetterTogether::Role.find_by(identifier: 'community_manager', resource_type: 'BetterTogether::Community') ||
      create(:better_together_role,
             identifier: 'community_manager',
             name: 'Community Manager',
             resource_type: 'BetterTogether::Community')
  end
  let(:manager) { create(:better_together_person) }
  let!(:manager_membership) do
    create(:better_together_person_community_membership,
           :active,
           joinable: community,
           member: manager,
           role: community_manager_role)
  end

  def build_subscription_for(owner:, status:)
    pay_customer = create('pay/customer', owner:)
    pay_subscription = create('pay/subscription', customer: pay_customer, status:)

    create('better_together/billing/subscription', pay_subscription:)
  end

  around do |example|
    original = ENV.fetch('BT_BILLING_HOSTED_ACCESS_GRACE_PERIOD_DAYS', nil)
    ENV['BT_BILLING_HOSTED_ACCESS_GRACE_PERIOD_DAYS'] = '7'
    example.run
  ensure
    ENV['BT_BILLING_HOSTED_ACCESS_GRACE_PERIOD_DAYS'] = original
  end

  before do
    ActiveJob::Base.queue_adapter = :test
    Noticed::Notification.destroy_all
  end

  it 'notifies community managers exactly once for a subscription in its grace period' do
    subscription = build_subscription_for(owner: community, status: 'canceled')
    subscription.sync_lapse_state!

    expect { described_class.new.perform }.to change(Noticed::Notification, :count).by(1)

    notification = Noticed::Notification.last
    expect(notification.recipient).to eq(manager)
    expect(notification.event.type).to eq('BetterTogether::Billing::HostedAccessGraceNotifier')
    expect(subscription.reload.grace_notice_sent?).to be(true)
  end

  it 'does not notify again on a subsequent scan once the notice has already been sent' do
    subscription = build_subscription_for(owner: community, status: 'canceled')
    subscription.sync_lapse_state!
    described_class.new.perform

    expect { described_class.new.perform }.not_to change(Noticed::Notification, :count)
  end

  it 'does not notify a subscription that has not been lapse-tracked at all' do
    build_subscription_for(owner: community, status: 'canceled')

    expect { described_class.new.perform }.not_to change(Noticed::Notification, :count)
  end

  it 'does not notify once the grace period has expired (nothing left to warn about)' do
    subscription = build_subscription_for(owner: community, status: 'canceled')
    subscription.sync_lapse_state!

    travel_to(8.days.from_now) do
      expect { described_class.new.perform }.not_to change(Noticed::Notification, :count)
    end
  end

  it 'does not notify a subscription that recovered before the scan ran' do
    subscription = build_subscription_for(owner: community, status: 'canceled')
    subscription.sync_lapse_state!
    subscription.pay_subscription.update!(status: 'active')
    subscription.sync_lapse_state!

    expect { described_class.new.perform }.not_to change(Noticed::Notification, :count)
  end

  it 'skips a lapsed subscription whose beneficiary is a Person, not a Community' do
    person = create(:better_together_person)
    subscription = build_subscription_for(owner: person, status: 'canceled')
    subscription.sync_lapse_state!

    expect { described_class.new.perform }.not_to change(Noticed::Notification, :count)
    expect(subscription.reload.grace_notice_sent?).to be(false)
  end

  it 'does not mark the notice sent for a community with no manager/administrator, so a later scan retries' do
    unmanaged_community = create(:better_together_community)
    subscription = build_subscription_for(owner: unmanaged_community, status: 'canceled')
    subscription.sync_lapse_state!

    expect { described_class.new.perform }.not_to change(Noticed::Notification, :count)
    expect(subscription.reload.grace_notice_sent?).to be(false)

    create(:better_together_person_community_membership, :active,
           joinable: unmanaged_community, member: create(:better_together_person), role: community_manager_role)

    expect { described_class.new.perform }.to change(Noticed::Notification, :count).by(1)
    expect(subscription.reload.grace_notice_sent?).to be(true)
  end
end
