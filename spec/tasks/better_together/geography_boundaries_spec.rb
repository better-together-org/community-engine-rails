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
      .and_return({ imported: 3, skipped: 2, skipped_known_missing: 4, unsupported: 1, failed: 0, planned: [] })

    expect { task.invoke }.to output(
      /Boundary import complete: 3 fetched, 2 already had a boundary, 4 remembered as having no polygon, 1 had no usable/
    ).to_stdout
  end

  context 'with options in the environment' do
    around do |example|
      keys = %w[LEVEL IDENTIFIER FORCE DRY_RUN THRESHOLD]
      saved = ENV.values_at(*keys)
      example.run
      keys.zip(saved) { |key, value| ENV[key] = value }
    end

    it 'passes them to the import, and lists the plan on a dry run', :aggregate_failures do
      ENV.update('LEVEL' => 'settlement, region', 'IDENTIFIER' => 'corner-brook', 'FORCE' => '1', 'DRY_RUN' => '1',
                 'THRESHOLD' => '0.002')
      task.reenable
      allow(BetterTogether::Geography::BoundaryImportJob).to receive(:import_all_missing)
        .and_return({ planned: ['settlement/corner-brook'] })

      expect { task.invoke }.to output(%r{1 record\(s\) would be fetched\n  settlement/corner-brook}).to_stdout
      expect(BetterTogether::Geography::BoundaryImportJob).to have_received(:import_all_missing).with(
        levels: %w[settlement region], identifiers: ['corner-brook'], force: true, dry_run: true, threshold: 0.002
      )
    end
  end
end
