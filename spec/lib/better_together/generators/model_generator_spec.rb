# frozen_string_literal: true

require 'generator_spec'
require 'rails_helper'
require 'tmpdir'
require BetterTogether::Engine.root.join('lib/generators/better_together/model/model_generator')

RSpec.describe BetterTogether::Generators::ModelGenerator, type: :generator do
  around do |example|
    tmp_dir = Dir.mktmpdir('bt-model-generator-')
    self.class.destination(tmp_dir)
    prepare_destination
    example.run
  ensure
    FileUtils.rm_rf(tmp_dir) if tmp_dir
  end

  def migration_source
    Dir[File.join(destination_root, 'db/migrate/*_create_*.rb')].map { |f| File.read(f) }.join
  end

  describe 'engine namespace with translatable, privacy and friendly id' do
    before do
      run_generator(%w[project budget:integer --namespace=BetterTogether --translatable=name description
                       --privacy --friendly-id])
    end

    it 'creates the model with concerns and translations' do
      assert_file 'app/models/better_together/project.rb' do |content|
        expect(content).to include('class Project < BetterTogether::PlatformRecord',
                                   'include BetterTogether::Privacy', 'include BetterTogether::Translatable',
                                   'translates :name, type: :string', 'translates :description, type: :string',
                                   'slugged :name')
      end
    end

    it 'creates a create_bt_table migration with privacy and platform' do
      expect(migration_source).to include('create_bt_table :projects do |t|', 't.integer :budget', 't.bt_privacy',
                                          't.bt_references :platform')
    end

    it 'creates factory, specs, policy, resource and four locale files' do
      %w[spec/factories/better_together/projects.rb spec/models/better_together/project_spec.rb
         app/policies/better_together/project_policy.rb spec/policies/better_together/project_policy_spec.rb
         app/resources/better_together/api/v1/project_resource.rb].each { |path| assert_file path }
      %w[en es fr uk].each { |locale| assert_file "config/locales/project.#{locale}.yml", /^#{locale}:/ }
    end

    it 'generates syntactically valid Ruby' do
      Dir[File.join(destination_root, '**/*.rb')].each do |path|
        expect { RubyVM::InstructionSequence.compile(File.read(path)) }.not_to raise_error, path
      end
    end

    it 'registers the resource under the Api::V1 namespace' do
      assert_file 'app/resources/better_together/api/v1/project_resource.rb' do |content|
        expect(content).to include('class ProjectResource < ::BetterTogether::Api::ApplicationResource',
                                   "model_name '::BetterTogether::Project'", 'attributes :name, :description, :budget')
      end
    end
  end

  describe 'host app without namespace' do
    before do
      run_generator(%w[note --no-platform-scoped --skip-resource --skip-policy])
    end

    it 'creates a root-level model on ApplicationRecord and a prefix-free table' do
      assert_file 'app/models/note.rb', /class Note < ApplicationRecord/
      expect(migration_source).to include('create_bt_table :notes, prefix: nil')
    end

    it 'skips the policy and resource' do
      assert_no_file 'app/policies/note_policy.rb'
      assert_no_file 'app/resources/api/v1/note_resource.rb'
    end
  end
end
