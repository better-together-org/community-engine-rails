# frozen_string_literal: true

require 'rails_helper'

# Explicitly load the configuration file since it may not be autoloaded
require_relative '../../../lib/better_together/configuration'

RSpec.describe BetterTogether::Configuration do
  subject(:configuration) { described_class.new }

  describe 'attribute readers' do
    it { is_expected.to respond_to(:base_url) }
    it { is_expected.to respond_to(:new_user_password_path) }
    it { is_expected.to respond_to(:user_class) }
    it { is_expected.to respond_to(:user_confirmation_path) }
  end

  describe 'delegation to BetterTogether module' do
    describe '#base_url=' do
      it 'delegates to BetterTogether.base_url=' do
        expect(BetterTogether).to receive(:base_url=).with('http://example.com')
        configuration.base_url = 'http://example.com'
      end

      it 'allows setting base_url' do
        configuration.base_url = 'http://test.com'
        expect(BetterTogether.base_url).to eq('http://test.com')
      end
    end

    describe '#new_user_password_path=' do
      it 'delegates to BetterTogether.new_user_password_path=' do
        expect(BetterTogether).to receive(:new_user_password_path=).with('/reset')
        configuration.new_user_password_path = '/reset'
      end

      it 'allows setting new_user_password_path' do
        configuration.new_user_password_path = '/custom/reset'
        expect(BetterTogether.new_user_password_path).to eq('/custom/reset')
      end
    end

    describe '#user_class=' do
      it 'delegates to BetterTogether.user_class=' do
        expect(BetterTogether).to receive(:user_class=).with('CustomUser')
        configuration.user_class = 'CustomUser'
      end

      it 'allows setting user_class' do
        configuration.user_class = '::BetterTogether::User'
        expect(BetterTogether.user_class).to eq(BetterTogether::User)
      end
    end

    describe '#user_confirmation_path=' do
      it 'delegates to BetterTogether.user_confirmation_path=' do
        expect(BetterTogether).to receive(:user_confirmation_path=).with('/confirm')
        configuration.user_confirmation_path = '/confirm'
      end

      it 'allows setting user_confirmation_path' do
        configuration.user_confirmation_path = '/custom/confirm'
        expect(BetterTogether.user_confirmation_path).to eq('/custom/confirm')
      end
    end
  end

  describe 'configuration pattern' do
    it 'can be used in a block configuration style' do
      config = described_class.new

      config.base_url = 'http://configured.com'
      config.user_class = '::BetterTogether::User'

      expect(BetterTogether.base_url).to eq('http://configured.com')
      expect(BetterTogether.user_class).to eq(BetterTogether::User)
    end

    it 'maintains configuration state across instances' do
      config1 = described_class.new
      config1.base_url = 'http://first.com'

      described_class.new
      expect(BetterTogether.base_url).to eq('http://first.com')
    end
  end

  describe 'integration with BetterTogether module' do
    before do
      # Reset configuration
      BetterTogether.base_url = nil
      BetterTogether.user_class = nil
      BetterTogether.new_user_password_path = nil
      BetterTogether.user_confirmation_path = nil
    end

    it 'allows full configuration setup' do
      config = described_class.new

      config.base_url = 'http://example.com'
      config.user_class = '::BetterTogether::User'
      config.new_user_password_path = '/passwords/new'
      config.user_confirmation_path = '/users/confirmation'

      expect(BetterTogether.base_url).to eq('http://example.com')
      expect(BetterTogether.user_class).to eq(BetterTogether::User)
      expect(BetterTogether.new_user_password_path).to eq('/passwords/new')
      expect(BetterTogether.user_confirmation_path).to eq('/users/confirmation')
    end
  end
end
