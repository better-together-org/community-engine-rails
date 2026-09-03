# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'better_together:geography:backfill_placements rake task', type: :task do
  before do
    Rake.application&.clear
    Rake.application = Rake::Application.new
    load BetterTogether::Engine.root.join('lib/tasks/better_together/geography_backfill_placements.rake')
    Rake::Task.define_task(:environment)
  end

  after do
    Rake.application&.clear
  end

  let(:task) { Rake::Task['better_together:geography:backfill_placements'] }

  it 'delegates to HierarchyResolutionJob.backfill_all_missing and prints the summary' do
    task.reenable

    allow(BetterTogether::Geography::HierarchyResolutionJob).to receive(:backfill_all_missing)
      .and_return({ enqueued: 4 })

    expect { task.invoke }.to output(/Geography placement backfill complete: 4 record\(s\) enqueued/).to_stdout
  end
end
