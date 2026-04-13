# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe BetterTogether::Elasticsearch::Documents::Content::Markdown do
  describe '#indexed_elasticsearch_content' do
    let(:markdown) do
      record = nil
      I18n.with_locale(:en) do
        record = create(:content_markdown, markdown_source: '# English **content**')
      end
      I18n.with_locale(:es) do
        record.update!(markdown_source: '# Contenido **español**')
      end
      I18n.with_locale(:fr) do
        record.update!(markdown_source: '# Contenu **français**')
      end
      record
    end

    it 'indexes plain-text content for all available locales' do
      result = markdown.indexed_elasticsearch_content

      expect(result[:localized_content][:en]).to include('English')
      expect(result[:localized_content][:en]).to include('content')
      expect(result[:localized_content][:en]).not_to include('**')

      expect(result[:localized_content][:es]).to include('Contenido')
      expect(result[:localized_content][:es]).to include('español')

      expect(result[:localized_content][:fr]).to include('Contenu')
      expect(result[:localized_content][:fr]).to include('français')
    end

    it 'strips HTML from indexed content' do
      result = markdown.indexed_elasticsearch_content

      I18n.available_locales.each do |locale|
        expect(result[:localized_content][locale]).not_to match(/<[^>]+>/)
      end
    end
  end
end
