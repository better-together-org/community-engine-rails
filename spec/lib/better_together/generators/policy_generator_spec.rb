# frozen_string_literal: true

require 'generator_spec'
require 'rails_helper'
require 'tmpdir'
require BetterTogether::Engine.root.join('lib/generators/better_together/policy/policy_generator')

RSpec.describe BetterTogether::Generators::PolicyGenerator, type: :generator do
  around do |example|
    tmp_dir = Dir.mktmpdir('bt-policy-generator-')
    self.class.destination(tmp_dir)
    prepare_destination
    example.run
  ensure
    FileUtils.rm_rf(tmp_dir) if tmp_dir
  end

  def valid_ruby?(path)
    RubyVM::InstructionSequence.compile(File.read(File.join(destination_root, path)))
  end

  it 'creates a namespaced platform record policy and spec' do
    run_generator(%w[project --namespace=BetterTogether])

    assert_file 'app/policies/better_together/project_policy.rb',
                /class ProjectPolicy < BetterTogether::PlatformRecordPolicy/
    assert_file 'spec/policies/better_together/project_policy_spec.rb'
    expect(valid_ruby?('app/policies/better_together/project_policy.rb')).to be_truthy
  end

  it 'creates a root-level ApplicationPolicy subclass in a host app' do
    run_generator(%w[note --no-platform-record --namespace=])

    assert_file 'app/policies/note_policy.rb', /^class NotePolicy < BetterTogether::ApplicationPolicy/
  end
end
