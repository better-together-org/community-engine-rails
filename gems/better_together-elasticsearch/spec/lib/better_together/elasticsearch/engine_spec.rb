# frozen_string_literal: true

require_relative '../../../rails_helper'

RSpec.describe BetterTogether::Elasticsearch::Engine do
  describe '.model_document_integration_enabled?' do
    it 'returns true when the elasticsearch backend is selected explicitly' do
      expect(described_class.model_document_integration_enabled?('SEARCH_BACKEND' => 'elasticsearch')).to be(true)
    end

    it 'returns false when only elasticsearch connection settings are present' do
      expect(described_class.model_document_integration_enabled?('ELASTICSEARCH_URL' => 'http://example.test:9200')).to be(false)
    end

    it 'returns false when neither backend selection nor connection settings are present' do
      expect(described_class.model_document_integration_enabled?({})).to be(false)
    end
  end
end
