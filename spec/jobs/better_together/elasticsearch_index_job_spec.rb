# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ElasticsearchIndexJob do
  let(:backend) { instance_double(BetterTogether::Search::ElasticsearchBackend) }
  let(:record) { create(:better_together_page) }

  before do
    allow(BetterTogether::Search).to receive(:backend).and_return(backend)
  end

  it 'indexes a searchable record on index action' do
    expect(backend).to receive(:index_record).with(record)

    described_class.perform_now(record, :index)
  end

  it 'deletes a searchable record on delete action' do
    expect(backend).to receive(:delete_record).with(record)

    described_class.perform_now(record, :delete)
  end

  it 'delegates to the configured backend even when the record lacks elasticsearch helpers' do
    plain_record = instance_double(String, to_global_id: 'gid://test/String/1')

    expect(backend).to receive(:index_record).with(plain_record)

    described_class.perform_now(plain_record, :index)
  end

  it 'raises on unknown actions' do
    expect do
      described_class.perform_now(record, :bogus)
    end.to raise_error(ArgumentError, 'Unknown action: bogus')
  end
end
