# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::TemplateRendererService do
  describe '#render_for_all_locales' do
    context 'with a valid template path' do
      let(:service) { described_class.new('better_together/static_pages/privacy') }

      it 'renders content for all available locales' do
        result = service.render_for_all_locales

        expect(result).to be_a(Hash)
        expect(result.keys).to match_array(I18n.available_locales)
      end

      it 'returns plain text content for each locale' do
        result = service.render_for_all_locales

        I18n.available_locales.each do |locale|
          expect(result[locale]).to be_a(String)
          expect(result[locale]).not_to be_empty
          # Should not contain HTML tags
          expect(result[locale]).not_to match(/<[^>]+>/)
        end
      end

      it 'extracts meaningful text from the template' do
        result = service.render_for_all_locales

        expect(result[:en]).to include('Better Together')
        expect(result[:en]).to include('privacy')
      end
    end

    context 'with an invalid template path' do
      let(:service) { described_class.new('nonexistent/template') }

      it 'returns the template path as fallback' do
        result = service.render_for_all_locales

        I18n.available_locales.each do |locale|
          expect(result[locale]).to eq('nonexistent/template')
        end
      end

      it 'logs a warning for each locale' do
        expect(Rails.logger).to receive(:warn).with(/Failed to render template/).exactly(I18n.available_locales.count).times
        service.render_for_all_locales
      end
    end
  end

  describe '#render_for_current_locale' do
    let(:service) { described_class.new('better_together/static_pages/privacy') }

    it 'renders content for the current locale only' do
      I18n.with_locale(:en) do
        result = service.render_for_current_locale

        expect(result).to be_a(String)
        expect(result).not_to be_empty
      end
    end

    it 'returns plain text without HTML tags' do
      result = service.render_for_current_locale

      expect(result).not_to match(/<[^>]+>/)
    end

    it 'respects the current locale' do
      I18n.with_locale(:en) do
        result_en = service.render_for_current_locale
        expect(result_en).to include('Better Together')
      end

      I18n.with_locale(:es) do
        result_es = service.render_for_current_locale
        # Spanish content may differ
        expect(result_es).to be_a(String)
      end
    end
  end

  describe 'template path handling' do
    context 'with static page template' do
      it 'correctly handles better_together/static_pages/ prefix' do
        service = described_class.new('better_together/static_pages/privacy')
        result = service.render_for_current_locale

        expect(result).to be_a(String)
        expect(result).not_to be_empty
      end
    end

    context 'with partial template' do
      it 'handles template paths for partials' do
        # Create a test template block
        template = BetterTogether::Content::Template.create!(
          template_path: 'better_together/content/blocks/template/default'
        )

        service = described_class.new(template.template_path)
        result = service.render_for_current_locale

        expect(result).to be_a(String)
      end
    end
  end

  describe 'plain text extraction' do
    let(:service) { described_class.new('better_together/static_pages/privacy') }

    it 'removes HTML tags' do
      result = service.render_for_current_locale

      expect(result).not_to match(/<p>/)
      expect(result).not_to match(/<div>/)
      expect(result).not_to match(/<h1>/)
      expect(result).not_to match(/<a[^>]*>/)
    end

    it 'normalizes whitespace' do
      result = service.render_for_current_locale

      # Should not have multiple consecutive spaces
      expect(result).not_to match(/\s{2,}/)
      # Should not have leading/trailing whitespace
      expect(result).to eq(result.strip)
    end

    it 'preserves text content from HTML' do
      result = service.render_for_current_locale

      # Should contain actual text content
      expect(result.length).to be > 100
      expect(result).to match(/\w+/)
    end
  end

  describe 'error handling' do
    context 'when rendering fails' do
      let(:service) { described_class.new('bad/template') }

      it 'does not raise an exception' do
        expect { service.render_for_all_locales }.not_to raise_error
      end

      it 'returns the template path as fallback' do
        result = service.render_for_current_locale
        expect(result).to eq('bad/template')
      end
    end
  end

  describe 'integration with Template model' do
    let(:template_block) do
      BetterTogether::Content::Template.create!(
        template_path: 'better_together/static_pages/privacy'
      )
    end

    it 'is used by Template#indexed_localized_content' do
      result = template_block.indexed_localized_content

      expect(result).to be_a(Hash)
      expect(result.keys).to match_array(I18n.available_locales)
      result.each_value do |content|
        expect(content).to be_a(String)
        expect(content).not_to be_empty
      end
    end
  end

  describe 'performance' do
    let(:service) { described_class.new('better_together/static_pages/privacy') }

    it 'caches the view context' do
      # First call should create view context
      service.render_for_current_locale

      # Second call should reuse it
      expect(ApplicationController).not_to receive(:new)
      service.render_for_current_locale
    end
  end
end
