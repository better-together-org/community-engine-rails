# frozen_string_literal: true

require 'rails_helper'

# Engine migrations run both in the engine's dummy app and in host apps that migrate
# from the gem, so they must not depend on either app's rake namespace or on models
# whose columns are added by later migrations (see bin/ci-migrate-from-zero).
RSpec.describe BetterTogether::MigrationHelpers do
  let(:migration_files) { Dir[BetterTogether::Engine.root.join('db/migrate/*.rb')] }

  it 'finds the engine migrations to check' do
    expect(migration_files).not_to be_empty
  end

  it 'never calls Rake::Task directly or hard-codes the dummy app: namespace' do
    offenders = migration_files.select { |file| File.read(file).match?(/Rake::Task\[|['"]app:/) }

    expect(offenders.map { |file| File.basename(file) }).to be_empty
  end

  describe '#run_engine_rake_task' do
    let(:migration) { Class.new(ActiveRecord::Migration::Current).new }

    it 'raises when the rake task is not defined' do
      expect { migration.run_engine_rake_task('better_together:no_such_task') }
        .to raise_error(ArgumentError, /not defined/)
    end

    it 'invokes a defined task more than once' do
      calls = 0
      Rake::Task.define_task('better_together:portability_probe') { calls += 1 }

      2.times { migration.run_engine_rake_task('better_together:portability_probe') }

      expect(calls).to eq(2)
    end

    it 'skips the task when the listed tables have no rows' do
      Rake::Task.define_task('better_together:portability_skip') { raise 'should not run' }

      expect do
        migration.run_engine_rake_task('better_together:portability_skip',
                                       skip_when_empty: %i[better_together_no_such_table])
      end.not_to raise_error
    end
  end
end
