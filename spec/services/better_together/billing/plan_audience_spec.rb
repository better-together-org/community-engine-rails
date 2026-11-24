# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::PlanAudience do
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:counts) { described_class.active_subscriber_counts(host_platform.billing_plans.to_a) }

  it 'counts only active subscribers, per plan', :aggregate_failures do
    start_subscription
    start_subscription(payer: create(:better_together_person))
    ended = start_subscription(payer: create(:better_together_person))
    BetterTogether::Billing::Subscriptions::Cancel.call(term: ended, now: true)

    expect(counts[sub_plan.id]).to eq(2)
    expect(counts.fetch(create(:better_together_billing_plan).id, 0)).to eq(0)
  end

  it 'asks the database once however many plans there are' do
    plans = Array.new(3) { create(:better_together_billing_plan) }
    queries = []
    counter = ->(*, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') { described_class.active_subscriber_counts(plans) }

    expect(queries.size).to eq(1)
  end
end
