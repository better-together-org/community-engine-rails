# frozen_string_literal: true

require 'generator_spec'
require 'rails_helper'
require 'tmpdir'
require BetterTogether::Engine.root.join('lib/generators/better_together/resource/resource_generator')

RSpec.describe BetterTogether::Generators::ResourceGenerator, type: :generator do
  around do |example|
    tmp_dir = Dir.mktmpdir('bt-resource-generator-')
    self.class.destination(tmp_dir)
    prepare_destination
    example.run
  ensure
    FileUtils.rm_rf(tmp_dir) if tmp_dir
  end

  def valid_ruby?(path)
    RubyVM::InstructionSequence.compile(File.read(File.join(destination_root, path)))
  end

  it 'creates a nested Api::V1 resource with attributes' do
    run_generator(%w[project name:string budget:integer --namespace=BetterTogether])

    assert_file 'app/resources/better_together/api/v1/project_resource.rb' do |content|
      expect(content).to include('module Api', 'module V1', 'class ProjectResource', 'attributes :name, :budget',
                                 "model_name '::BetterTogether::Project'")
    end
    expect(valid_ruby?('app/resources/better_together/api/v1/project_resource.rb')).to be_truthy
  end
end
