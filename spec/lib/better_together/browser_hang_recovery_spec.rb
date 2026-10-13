# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BrowserHangRecovery do
  describe '.hung?' do
    it 'is true for a Selenium read timeout and for the per-attempt Timeout' do
      expect([Net::ReadTimeout.new, Timeout::Error.new].map { |error| described_class.hung?(error) }).to all(be(true))
    end

    it 'is true when RSpec wraps a timeout with other failures' do
      wrapped = RSpec::Core::MultipleExceptionError.new(StandardError.new('boom'), Net::ReadTimeout.new)

      expect(described_class.hung?(wrapped)).to be(true)
    end

    it 'is false for ordinary failures and for no failure' do
      expect([StandardError.new('boom'), nil].map { |error| described_class.hung?(error) }).to all(be(false))
    end
  end

  describe '.discard_browser' do
    it 'quits the current session driver' do
      driver = instance_double(Capybara::Selenium::Driver, quit: nil)
      allow(Capybara).to receive(:current_session).and_return(instance_double(Capybara::Session, driver:))

      described_class.discard_browser

      expect(driver).to have_received(:quit)
    end

    it 'does not raise when the driver cannot quit' do
      allow(Capybara).to receive(:current_session).and_raise(StandardError, 'no session')

      expect { described_class.discard_browser }.not_to raise_error
    end
  end
end
