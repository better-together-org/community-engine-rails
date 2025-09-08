# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Builder do
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
      expect { described_class.seed_data }
        .to raise_error('seed_data should be implemented in your child class')
    end
  end

  describe '.clear_existing' do
    it 'raises when not implemented' do
      expect { described_class.clear_existing }
        .to raise_error('clear_existing should be implemented in your child class')
    end
  end

  describe '.build' do
    it 'calls seed_data without clear when clear: false' do
      expect(subclass).to receive(:seed_data) # rubocop:todo RSpec/MessageSpies
      expect(subclass).not_to receive(:clear_existing) # rubocop:todo RSpec/MessageSpies
      subclass.build(clear: false)
    end

    it 'calls clear_existing and seed_data when clear: true' do
      expect(subclass).to receive(:clear_existing).ordered # rubocop:todo RSpec/MessageSpies
      expect(subclass).to receive(:seed_data).ordered # rubocop:todo RSpec/MessageSpies
      subclass.build(clear: true)
    end
  end
end
