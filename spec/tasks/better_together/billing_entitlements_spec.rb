# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'better_together:billing:entitlements:backfill_hosted_access rake task', type: :task do
  before do
    Rake.application&.clear
    Rake.application = Rake::Application.new
    load BetterTogether::Engine.root.join('lib/tasks/better_together/billing_entitlements.rake')
    Rake::Task.define_task(:environment)
  end

  after do
    Rake.application&.clear
    ENV.delete('DRY_RUN')
  end

  let(:task) { Rake::Task['better_together:billing:entitlements:backfill_hosted_access'] }
  let(:community) { create(:better_together_community) }
  let(:plan) { create('better_together/billing/plan', metadata: { 'grants_entitlements' => ['hosted_access'] }) }

  def create_subscription_for(owner:, billing_plan:, status:)
    pay_customer = create('pay/customer', owner:)
    pay_subscription = create('pay/subscription', customer: pay_customer, status:)

    create('better_together/billing/subscription', pay_subscription:, billing_plan:)
  end

  it 'reports zero eligible subscriptions when none exist' do
    task.reenable

    expect { task.invoke }.to output(a_string_including('Found 0 access_active subscription')).to_stdout
  end

  it 'grants hosted_access for an access_active subscription whose plan declares it' do
    create_subscription_for(owner: community, billing_plan: plan, status: 'active')
    task.reenable

    expect { task.invoke }.to output(a_string_including("granted hosted_access to #{community.class.name}")).to_stdout
    expect(community.entitled_to?('hosted_access')).to be(true)
  end

  it 'skips a subscription whose plan does not declare grants_entitlements' do
    bare_plan = create('better_together/billing/plan')
    create_subscription_for(owner: community, billing_plan: bare_plan, status: 'active')
    task.reenable

    task.invoke

    expect(community.entitled_to?('hosted_access')).to be(false)
  end

  it 'skips a subscription that is not access_active and never lapse-tracked' do
    create_subscription_for(owner: community, billing_plan: plan, status: 'canceled')
    task.reenable

    task.invoke

    expect(community.entitled_to?('hosted_access')).to be(false)
  end

  it 'makes no changes when DRY_RUN is set' do
    create_subscription_for(owner: community, billing_plan: plan, status: 'active')
    ENV['DRY_RUN'] = 'true'
    task.reenable

    expect { task.invoke }.to output(a_string_including('[dry run] would grant hosted_access')).to_stdout
    expect(community.entitled_to?('hosted_access')).to be(false)
  end
end
