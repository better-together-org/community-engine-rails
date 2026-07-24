# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'better_together:geography:import_boundaries rake task', type: :task do
  before do
    Rake.application&.clear
    Rake.application = Rake::Application.new
    load BetterTogether::Engine.root.join('lib/tasks/better_together/geography_boundaries.rake')
    Rake::Task.define_task(:environment)
  end

  after do
    Rake.application&.clear
  end

  let(:task) { Rake::Task['better_together:geography:import_boundaries'] }

  it 'delegates to BoundaryImportJob.import_all_missing and prints the summary' do
    task.reenable

    allow(BetterTogether::Geography::BoundaryImportJob).to receive(:import_all_missing)
      .and_return({ imported: 3, skipped: 2 })

    expect { task.invoke }.to output(/Boundary import complete: 3 fetched, 2 already had a boundary/).to_stdout
  end
end
