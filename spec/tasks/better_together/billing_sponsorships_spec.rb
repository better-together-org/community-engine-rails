# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'better_together:billing:sponsorships:detect_legacy_metadata_sponsorships rake task', type: :task do
  before do
    Rake.application&.clear
    Rake.application = Rake::Application.new
    load BetterTogether::Engine.root.join('lib/tasks/better_together/billing_sponsorships.rake')
    Rake::Task.define_task(:environment)
  end

  after do
    Rake.application&.clear
  end

  let(:task) { Rake::Task['better_together:billing:sponsorships:detect_legacy_metadata_sponsorships'] }

  it 'reports no legacy sponsorships when none exist' do
    task.reenable

    expect { task.invoke }.to output(a_string_including('No legacy metadata-based sponsorships found.')).to_stdout
  end

  it 'reports subscriptions still carrying legacy bt_beneficiary_type/id metadata, without modifying anything' do
    task.reenable
    sponsor = create(:better_together_person)
    legacy_beneficiary = create(:better_together_community, name: 'Legacy Beneficiary Co-op')
    subscription = create(:better_together_billing_subscription, billable_owner: sponsor)
    subscription.update_column( # rubocop:disable Rails/SkipsModelValidations
      :metadata,
      {
        'bt_beneficiary_type' => legacy_beneficiary.class.name,
        'bt_beneficiary_id' => legacy_beneficiary.id
      }
    )

    expect { task.invoke }.to output(
      a_string_including('Found 1 subscription').and(
        a_string_including('Legacy Beneficiary Co-op')
      )
    ).to_stdout

    expect(subscription.reload.metadata['bt_beneficiary_type']).to eq(legacy_beneficiary.class.name)
  end
end
