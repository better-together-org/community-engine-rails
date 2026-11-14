# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe Rails81JSONAPIResourcesCompat do
    it 'keeps the legacy constant alias available' do
      expect(BetterTogether::Rails81JsonapiResourcesCompat).to be(described_class)
    end

    it 'turns a positional options hash into keywords for resources' do
      mapper_class = Class.new do
        def resources(*names, **options)
          [names, options]
        end
      end
      mapper_class.prepend(BetterTogether::Rails81JSONAPIResourcesCompat::MapperResourcesKeywordCompat)

      expect(mapper_class.new.resources(:people, { only: %i[index], path: 'folks' }, param: :slug))
        .to eq([[:people], { only: %i[index], path: 'folks', param: :slug }])
    end
  end
end
