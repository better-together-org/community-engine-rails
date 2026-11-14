# frozen_string_literal: true

require 'generator_spec'
require 'rails_helper'
require 'tmpdir'
require BetterTogether::Engine.root.join('lib/generators/better_together/notifier/notifier_generator')

RSpec.describe BetterTogether::Generators::NotifierGenerator, type: :generator do
  around do |example|
    tmp_dir = Dir.mktmpdir('bt-notifier-generator-')
    self.class.destination(tmp_dir)
    prepare_destination
    example.run
  ensure
    FileUtils.rm_rf(tmp_dir) if tmp_dir
  end

  def valid_ruby?(path)
    RubyVM::InstructionSequence.compile(File.read(File.join(destination_root, path)))
  end

  it 'creates a notifier with email delivery when a mailer is given' do
    run_generator(%w[new_reply --namespace=BetterTogether --mailer=BetterTogether::ReplyMailer])

    assert_file 'app/notifiers/better_together/new_reply_notifier.rb' do |content|
      expect(content).to include('class NewReplyNotifier < ApplicationNotifier', 'deliver_by :email')
    end
    expect(valid_ruby?('app/notifiers/better_together/new_reply_notifier.rb')).to be_truthy
    assert_file 'spec/notifiers/better_together/new_reply_notifier_spec.rb'
  end
end
