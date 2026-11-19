# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Seeds::TypeDefinition do
  describe '#stored_key' do
    it 'returns the form the model stores for a key it normalizes' do
      definition = BetterTogether::Seeds::Registry.fetch('navigation_item')

      expect(definition.stored_key('footer/group-legal')).to eq('footer-group-legal')
    end

    it 'returns the key unchanged when the model keeps it as given' do
      definition = BetterTogether::Seeds::Registry.fetch('navigation_area')

      expect(definition.stored_key('footer')).to eq('footer')
    end
  end
end
