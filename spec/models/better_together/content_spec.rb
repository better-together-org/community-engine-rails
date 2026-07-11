# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Content do
  describe '.table_name_prefix' do
    it 'returns the expected prefix' do
      expect(described_class.table_name_prefix).to eq('better_together_content_')
    end
  end

  describe 'IMAGE_CONTENT_TYPES' do
    it 'includes common web image types' do
      expect(described_class::IMAGE_CONTENT_TYPES).to include(
        'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/svg+xml'
      )
    end
  end

  describe 'CONTENT_TYPES' do
    it 'is a superset of IMAGE_CONTENT_TYPES' do
      described_class::IMAGE_CONTENT_TYPES.each do |type|
        expect(described_class::CONTENT_TYPES).to include(type)
      end
    end
  end
end
