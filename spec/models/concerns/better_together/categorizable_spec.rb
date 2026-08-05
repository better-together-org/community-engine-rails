# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Categorizable do
  describe '.category_klass' do
    it 'resolves the configured category class' do
      expect(BetterTogether::Event.category_klass).to eq(BetterTogether::EventCategory)
    end

    it 'raises NameError (not the resolver default ArgumentError) for a disallowed class name' do
      original = BetterTogether::Event.category_class_name
      BetterTogether::Event.category_class_name = 'BetterTogether::Page'

      expect { BetterTogether::Event.category_klass }.to raise_error(NameError)
    ensure
      BetterTogether::Event.category_class_name = original
    end
  end
end
