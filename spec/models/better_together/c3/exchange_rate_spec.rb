# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::C3::ExchangeRate do
  describe 'validations' do
    subject(:exchange_rate) do
      described_class.new(
        contribution_type: :volunteer,
        contribution_type_name: 'volunteer',
        rate: 50.0,
        unit_name: 'hour',
        unit_label: 'volunteer hour'
      )
    end

    it 'is valid with required attributes' do
      expect(exchange_rate).to be_valid
    end

    it 'requires rate' do
      exchange_rate.rate = nil
      expect(exchange_rate).not_to be_valid
    end

    it 'requires rate to be positive' do
      exchange_rate.rate = 0
      expect(exchange_rate).not_to be_valid
      exchange_rate.rate = -1
      expect(exchange_rate).not_to be_valid
    end

    it 'requires unit_name' do
      exchange_rate.unit_name = nil
      expect(exchange_rate).not_to be_valid
    end

    it 'requires unit_label' do
      exchange_rate.unit_label = nil
      expect(exchange_rate).not_to be_valid
    end

    it 'requires contribution_type' do
      exchange_rate.contribution_type = nil
      expect(exchange_rate).not_to be_valid
    end
  end

  describe 'CONTRIBUTION_TYPES constant' do
    it 'includes all expected contribution types' do
      expect(described_class::CONTRIBUTION_TYPES).to include(
        :compute_cpu, :compute_gpu, :volunteer, :embedding, :inference
      )
    end
  end

  describe 'enum :contribution_type' do
    it 'maps volunteer to integer 3' do
      described_class.new(contribution_type: :volunteer)
      expect(described_class.contribution_types[:volunteer]).to eq(3)
    end
  end

  describe '.active scope' do
    it 'returns only active exchange rates' do
      active_rate = described_class.create!(
        contribution_type: :volunteer, contribution_type_name: 'volunteer',
        rate: 50.0, unit_name: 'hour', unit_label: 'volunteer hour', active: true
      )
      inactive_rate = described_class.create!(
        contribution_type: :compute_cpu, contribution_type_name: 'compute_cpu',
        rate: 10.0, unit_name: 'cpu_hour', unit_label: 'CPU hour', active: false
      )

      active_scope = described_class.active
      expect(active_scope).to include(active_rate)
      expect(active_scope).not_to include(inactive_rate)
    end
  end

  describe '#to_s' do
    it 'includes the contribution type name and rate' do
      rate = described_class.new(
        contribution_type: :volunteer, contribution_type_name: 'volunteer',
        rate: 50.0, unit_name: 'hour', unit_label: 'volunteer hour'
      )
      expect(rate.to_s).to include('volunteer')
      expect(rate.to_s).to include('50.0')
      expect(rate.to_s).to include('hour')
    end
  end

  describe 'DEFAULT_RATES constant' do
    it 'has a rate entry for each contribution type' do
      default_type_names = described_class::DEFAULT_RATES.map { |r| r[:contribution_type_name] }
      expect(default_type_names).to include('compute_cpu', 'compute_gpu', 'volunteer', 'embedding')
    end

    it 'has positive rates for all defaults' do
      expect(described_class::DEFAULT_RATES).to all(satisfy { |r| r[:rate] > 0 })
    end
  end
end
