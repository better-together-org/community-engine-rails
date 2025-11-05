# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Users::RegistrationsController, :skip_host_setup, :user_registration do
  include BetterTogether::CapybaraFeatureHelpers

  routes { BetterTogether::Engine.routes }

  before do
    configure_host_platform
  end

  describe 'captcha hook methods', :no_auth do
    describe '#validate_captcha_if_enabled?' do
      let(:controller_instance) { described_class.new }

      it 'returns true by default (no captcha validation)' do
        expect(controller_instance.send(:validate_captcha_if_enabled?)).to be true
      end
    end

    describe '#handle_captcha_validation_failure' do
      let(:user) { build(:better_together_user) }
      let(:controller_instance) { described_class.new }

      before do
        allow(controller_instance).to receive(:respond_with)
      end

      it 'adds error to resource and calls respond_with' do
        controller_instance.send(:handle_captcha_validation_failure, user)

        expect(user.errors[:base]).to include('Security verification failed. Please try again.')
        expect(controller_instance).to have_received(:respond_with).with(user)
      end
    end
  end

  # Integration test for the complete captcha flow will be handled in feature specs
end
