# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe TranslationsController do
    let(:person) { create(:person) }
    let(:user) { create(:user, person:) }
    let(:translation_bot) { instance_double(BetterTogether::TranslationBot) }

    before do
      allow_any_instance_of(described_class).to receive_message_chain(:helpers, :current_person)
        .and_return(person)
      allow(BetterTogether::TranslationBot).to receive(:new).and_return(translation_bot)
    end

    describe 'POST #translate', :as_user do
      let(:content) { 'Hello, world!' }
      let(:source_locale) { 'en' }
      let(:target_locale) { 'es' }
      let(:translated_content) { '¡Hola, mundo!' }

      let(:valid_params) do
        {
          content:,
          source_locale:,
          target_locale:
        }
      end

      context 'with successful translation' do
        before do
          allow(translation_bot).to receive(:translate)
            .with(content,
                  target_locale:,
                  source_locale:,
                  initiator: person)
            .and_return(translated_content)

          post better_together.translations_translate_path(locale: I18n.default_locale),
               params: valid_params
        end

        it 'returns http success' do
          expect(response).to have_http_status(:success)
        end

        it 'returns translated content as JSON' do
          expect(response.content_type).to match(%r{application/json})
          json_response = JSON.parse(response.body)
          expect(json_response['translation']).to eq(translated_content)
        end

        it 'calls TranslationBot with correct parameters' do
          expect(translation_bot).to have_received(:translate)
            .with(content,
                  target_locale:,
                  source_locale:,
                  initiator: person)
        end
      end

      context 'with different locales' do
        let(:source_locale) { 'en' }
        let(:target_locale) { 'fr' }
        let(:translated_content) { 'Bonjour le monde!' }

        before do
          allow(translation_bot).to receive(:translate)
            .and_return(translated_content)

          post better_together.translations_translate_path(locale: I18n.default_locale),
               params: valid_params
        end

        it 'returns the French translation' do
          json_response = JSON.parse(response.body)
          expect(json_response['translation']).to eq(translated_content)
        end
      end

      context 'with complex HTML content' do
        let(:content) do
          '<div><h1>Hello</h1><p>This is a test</p></div>'
        end
        let(:translated_content) do
          '<div><h1>Hola</h1><p>Esta es una prueba</p></div>'
        end

        before do
          allow(translation_bot).to receive(:translate)
            .and_return(translated_content)

          post better_together.translations_translate_path(locale: I18n.default_locale),
               params: valid_params
        end

        it 'handles HTML content correctly' do
          json_response = JSON.parse(response.body)
          expect(json_response['translation']).to eq(translated_content)
        end
      end

      context 'when translation fails' do
        before do
          allow(translation_bot).to receive(:translate)
            .and_raise(StandardError, 'API connection failed')

          post better_together.translations_translate_path(locale: I18n.default_locale),
               params: valid_params
        end

        it 'returns unprocessable_content status' do
          expect(response).to have_http_status(:unprocessable_content)
        end

        it 'returns error message as JSON' do
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to eq('Translation failed: API connection failed')
        end
      end

      context 'when TranslationBot raises timeout error' do
        before do
          allow(translation_bot).to receive(:translate)
            .and_raise(Timeout::Error)

          post better_together.translations_translate_path(locale: I18n.default_locale),
               params: valid_params
        end

        it 'handles the error gracefully' do
          expect(response).to have_http_status(:unprocessable_content)
          json_response = JSON.parse(response.body)
          expect(json_response['error']).to include('Translation failed')
        end
      end

      context 'when content is empty' do
        let(:content) { '' }
        let(:translated_content) { '' }

        before do
          allow(translation_bot).to receive(:translate)
            .and_return(translated_content)

          post better_together.translations_translate_path(locale: I18n.default_locale),
               params: valid_params
        end

        it 'handles empty content' do
          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['translation']).to eq('')
        end
      end

      context 'when current_person is nil' do
        before do
          allow_any_instance_of(described_class).to receive_message_chain(:helpers, :current_person)
            .and_return(nil)
          allow(translation_bot).to receive(:translate)
            .with(content,
                  target_locale:,
                  source_locale:,
                  initiator: nil)
            .and_return(translated_content)

          post better_together.translations_translate_path(locale: I18n.default_locale),
               params: valid_params
        end

        it 'passes nil as initiator' do
          expect(translation_bot).to have_received(:translate)
            .with(content,
                  target_locale:,
                  source_locale:,
                  initiator: nil)
        end

        it 'still returns successful translation' do
          expect(response).to have_http_status(:success)
          json_response = JSON.parse(response.body)
          expect(json_response['translation']).to eq(translated_content)
        end
      end

      context 'with missing parameters' do
        it 'handles missing content parameter' do
          allow(translation_bot).to receive(:translate).and_return('')

          post better_together.translations_translate_path(locale: I18n.default_locale),
               params: { source_locale:, target_locale: }

          expect(response).to have_http_status(:success)
        end

        it 'handles missing source_locale parameter' do
          allow(translation_bot).to receive(:translate).and_return(translated_content)

          post better_together.translations_translate_path(locale: I18n.default_locale),
               params: { content:, target_locale: }

          expect(response).to have_http_status(:success)
        end

        it 'handles missing target_locale parameter' do
          allow(translation_bot).to receive(:translate).and_return(translated_content)

          post better_together.translations_translate_path(locale: I18n.default_locale),
               params: { content:, source_locale: }

          expect(response).to have_http_status(:success)
        end
      end

      context 'with special characters in content' do
        let(:content) { "Hello & welcome to <our> 'world'!" }
        let(:translated_content) { "¡Hola & bienvenido a <nuestro> 'mundo'!" }

        before do
          allow(translation_bot).to receive(:translate)
            .and_return(translated_content)

          post better_together.translations_translate_path(locale: I18n.default_locale),
               params: valid_params
        end

        it 'preserves special characters' do
          json_response = JSON.parse(response.body)
          expect(json_response['translation']).to eq(translated_content)
        end
      end
    end
  end
end
