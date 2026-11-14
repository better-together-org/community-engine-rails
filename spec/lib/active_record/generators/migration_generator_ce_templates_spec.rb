# frozen_string_literal: true

require 'generator_spec'
require 'rails_helper'
require 'tmpdir'
require 'rails/generators/active_record/migration/migration_generator'

RSpec.describe ActiveRecord::Generators::MigrationGenerator, type: :generator do
  around do |example|
    tmp_dir = Dir.mktmpdir('bt-template-generator-')
    self.class.destination(tmp_dir)
    prepare_destination
    BetterTogether::GeneratorTemplates.register([BetterTogether::Engine.root.join('lib/templates')])
    example.run
  ensure
    FileUtils.rm_rf(tmp_dir) if tmp_dir
  end

  def migration_source
    Dir[File.join(destination_root, 'db/migrate/*.rb')].map { |f| File.read(f) }.join
  end

  it 'emits create_bt_table with idempotency guards for better_together tables' do
    run_generator(%w[CreateBetterTogetherGadgets name:string platform:references{polymorphic}])

    expect(migration_source).to include('create_bt_table :gadgets', 'unless table_exists?(:better_together_gadgets)',
                                        't.bt_references :platform, polymorphic: true')
  end

  it 'emits a guarded plain table with uuid ids for host tables' do
    run_generator(%w[CreateWidgets name:string:uniq --primary-key-type=uuid])

    expect(migration_source).to include('create_table :widgets, id: :uuid', 'unless index_exists?(:widgets, :name)')
  end

  it 'guards added columns and references and uses uuid reference types' do
    run_generator(%w[AddRegionToWidgets region:references slug:string --primary-key-type=uuid])

    expect(migration_source).to include('unless column_exists?(:widgets, :region_id)', 'type: :uuid',
                                        'unless column_exists?(:widgets, :slug)')
  end

  it 'engine app_generators reach the host configuration' do
    expect(Rails.application.config.generators.templates.map(&:to_s))
      .to include(BetterTogether::Engine.root.join('lib/templates').to_s)
  end
end
