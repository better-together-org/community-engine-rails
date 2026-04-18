# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ApplicationController locale normalization' do
  let(:controller) { BetterTogether::ApplicationController.new }

  describe '#normalize_locale' do
    it 'returns exact available locales as strings' do
      expect(controller.send(:normalize_locale, :fr)).to eq('fr')
    end

    it 'normalizes case and separators before matching a partial locale' do
      expect(controller.send(:normalize_locale, 'EN_us')).to eq('en')
    end

    it 'falls back to the default locale for blank values' do
      expect(controller.send(:normalize_locale, '   ')).to eq(I18n.default_locale.to_s)
    end

    it 'returns the provided fallback for unsupported locales' do
      expect(controller.send(:normalize_locale, 'zz-ZZ', fallback: nil)).to be_nil
    end

    it 'logs unsupported locales when using the default fallback' do
      allow(Rails.logger).to receive(:warn)

      expect(controller.send(:normalize_locale, 'zz-ZZ')).to eq(I18n.default_locale.to_s)
      expect(Rails.logger).to have_received(:warn).with("Unsupported locale 'zz-ZZ', falling back")
    end
  end

  describe '#set_locale' do
    let(:session) { {} }
    let(:request) { instance_double(ActionDispatch::Request, env: {}) }
    let(:helpers_proxy) { double(current_person: nil) }

    before do
      allow(controller).to receive_messages(session:, request:)
    end

    it 'stores a normalized locale from params' do
      allow(controller).to receive_messages(
        params: ActionController::Parameters.new(locale: 'fr-CA'),
        helpers: helpers_proxy
      )

      controller.send(:set_locale)

      expect(I18n.locale.to_s).to eq('fr')
      expect(session[:locale]).to eq('fr')
    end

    it 'skips unsupported params and falls through to the session locale' do
      allow(controller).to receive_messages(
        params: ActionController::Parameters.new(locale: 'zz-ZZ'),
        helpers: helpers_proxy
      )
      session[:locale] = 'es'

      controller.send(:set_locale)

      expect(I18n.locale.to_s).to eq('es')
      expect(session[:locale]).to eq('es')
    end
  end
end
