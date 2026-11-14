# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Storage::ConnectionTest do
  let(:configuration) { build(:better_together_storage_configuration) }

  it 'passes for a working service' do
    expect(described_class.new(configuration).call).to be_ok
  end

  it 'reports a failure by error class only, without provider text', :aggregate_failures do
    allow(ActiveStorage::Service::DiskService).to receive(:new).and_raise(Errno::EACCES, 'secret-bucket-name')

    result = described_class.new(configuration).call

    expect(result).not_to be_ok
    expect(result.message).to eq('eacces')
    expect(result.message).not_to include('secret')
  end

  it 'fails when the read back differs' do
    service = instance_double(ActiveStorage::Service::DiskService, upload: nil, download: 'other', delete: nil)
    allow(ActiveStorage::Service).to receive(:configure).and_return(service)

    expect(described_class.new(configuration).call.message).to eq('read_back_mismatch')
  end

  it 'deletes the probe object after a failure' do
    service = instance_double(ActiveStorage::Service::DiskService, delete: nil)
    allow(service).to receive(:upload).and_raise(IOError)
    allow(ActiveStorage::Service).to receive(:configure).and_return(service)

    described_class.new(configuration).call

    expect(service).to have_received(:delete)
  end
end
