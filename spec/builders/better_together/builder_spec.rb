# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Builder do # rubocop:todo Metrics/BlockLength
  let(:subclass) do
    Class.new(BetterTogether::Builder) do
      class << self
        def seed_data = @seeded = true
        def clear_existing = @cleared = true
        def seeded? = @seeded
        def cleared? = @cleared
      end
    end
  end

  describe '.seed_data' do
    it 'raises when not implemented' do
      expect { BetterTogether::Builder.seed_data }
        .to raise_error('seed_data should be implemented in your child class')
    end
  end

  describe '.clear_existing' do
    it 'raises when not implemented' do
      expect { BetterTogether::Builder.clear_existing }
        .to raise_error('clear_existing should be implemented in your child class')
    end
  end

  describe '.build' do
    it 'calls seed_data without clear when clear: false' do
      expect(subclass).to receive(:seed_data)
      expect(subclass).not_to receive(:clear_existing)
      subclass.build(clear: false)
    end

    it 'calls clear_existing and seed_data when clear: true' do
      expect(subclass).to receive(:clear_existing).ordered
      expect(subclass).to receive(:seed_data).ordered
      subclass.build(clear: true)
    end
  end
end
