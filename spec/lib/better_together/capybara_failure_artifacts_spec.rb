# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'

RSpec.describe BetterTogether::CapybaraFailureArtifacts do
  let(:example) { instance_double(RSpec::Core::Example, full_description: 'Events page: shows "Next"!', location: './x_spec.rb:1') }
  let(:session) { instance_double(Capybara::Session, current_path: '', current_url: 'about:blank', html: '<html></html>') }

  let(:dir) { Pathname.new(Dir.mktmpdir) }

  before { allow(described_class).to receive(:directory).and_return(dir) }

  after { FileUtils.remove_entry(dir) }

  it 'builds a filesystem-safe name from the example description' do
    expect(described_class.basename(example)).to match(/\A\d{6}-events_page_shows_next\z/)
  end

  it 'writes html and a notes file even when the screenshot cannot be taken' do
    allow(session).to receive(:save_screenshot).and_raise(Selenium::WebDriver::Error::WebDriverError, 'no browser')
    allow(session).to receive(:driver).and_raise(NoMethodError)

    described_class.capture(example, session)

    files = Dir.children(dir).to_h { |name| [File.extname(name), name] }
    notes = File.read(dir.join(files['.txt']))
    expect(files.keys).to include('.html', '.txt')
    expect(notes).to include('screenshot not saved', 'console not saved', 'about:blank')
  end
end
