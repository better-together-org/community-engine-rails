# frozen_string_literal: true

require 'generator_spec'
require 'rails_helper'
require 'tmpdir'
require BetterTogether::Engine.root.join('lib/generators/better_together/mailer/mailer_generator')

RSpec.describe BetterTogether::Generators::MailerGenerator, type: :generator do
  around do |example|
    tmp_dir = Dir.mktmpdir('bt-mailer-generator-')
    self.class.destination(tmp_dir)
    prepare_destination
    example.run
  ensure
    FileUtils.rm_rf(tmp_dir) if tmp_dir
  end

  def valid_ruby?(path)
    RubyVM::InstructionSequence.compile(File.read(File.join(destination_root, path)))
  end

  it 'creates the mailer, one view per action and a spec' do
    run_generator(%w[reply notify --namespace=BetterTogether])

    assert_file 'app/mailers/better_together/reply_mailer.rb', /def notify\(recipient\)/
    assert_file 'app/views/better_together/reply_mailer/notify.html.erb', /better_together\.reply_mailer\.notify\.body/
    assert_file 'spec/mailers/better_together/reply_mailer_spec.rb'
    expect(valid_ruby?('app/mailers/better_together/reply_mailer.rb')).to be_truthy
  end
end
