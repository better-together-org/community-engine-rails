# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Content
    RSpec.describe PlanCatalogBlock do
      it 'is a subclass of Content::Block' do
        expect(described_class.superclass).to eq(BetterTogether::Content::Block)
      end

      it 'is content_addable' do
        expect(described_class.content_addable?).to be true
      end

      it 'permits every attribute it stores' do
        expect(described_class.extra_permitted_attributes).to include(*(described_class.storext_definitions.keys - BetterTogether::Content::Block.storext_definitions.keys).map(&:to_sym))
      end

      it 'defaults to six plans' do
        expect(described_class.new.item_limit).to eq(6)
      end

      it 'translates its heading' do
        expect(described_class.new(heading_en: 'Plans', heading_fr: 'Forfaits')).to have_attributes(heading_en: 'Plans', heading_fr: 'Forfaits')
      end

      it 'needs a limit from 1 to 24' do
        expect(described_class.new(item_limit: 0)).not_to be_valid
        expect(described_class.new(item_limit: 25)).not_to be_valid
        expect(described_class.new(item_limit: 24)).to be_valid
      end
    end
  end
end
