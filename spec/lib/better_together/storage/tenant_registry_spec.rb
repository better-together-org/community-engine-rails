# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Storage::TenantRegistry do
  subject(:registry) { ActiveStorage::Blob.services }

  let(:config) { create(:better_together_storage_configuration) }

  it 'is installed as the Active Storage service registry' do
    expect(registry).to be_a(described_class)
  end

  it 'still resolves services from storage.yml' do
    expect(registry.fetch(:local)).to be_a(ActiveStorage::Service::DiskService)
  end

  it 'builds a service named after the configuration from its row', :aggregate_failures do
    service = registry.fetch(config.storage_key)

    expect(service).to be_a(ActiveStorage::Service::DiskService)
    expect(service.name.to_s).to eq(config.storage_key)
  end

  it 'reuses the built service until the row changes', :aggregate_failures do
    first = registry.fetch(config.storage_key)
    expect(registry.fetch(config.storage_key)).to equal(first)

    config.update!(name: 'Renamed')
    travel_to(described_class::REFRESH_INTERVAL.from_now + 1.second) do
      expect(registry.fetch(config.storage_key)).not_to equal(first)
    end
  end

  it 'raises KeyError for a configuration that does not exist' do
    expect { registry.fetch("#{described_class::PREFIX}#{SecureRandom.uuid}") }.to raise_error(KeyError)
  end

  it 'yields the key instead of raising when a block is given' do
    key = "#{described_class::PREFIX}#{SecureRandom.uuid}"

    expect(registry.fetch(key) { |missing| missing }).to eq(key.to_sym)
  end

  it 'rebuilds after forget' do
    first = registry.fetch(config.storage_key)
    registry.forget(config.storage_key)

    expect(registry.fetch(config.storage_key)).not_to equal(first)
  end
end
