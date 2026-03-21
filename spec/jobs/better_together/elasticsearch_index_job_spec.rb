# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ElasticsearchIndexJob, type: :job do
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

  it 'ignores records without elasticsearch support' do
    plain_record = double('plain-record')

    expect(backend).not_to receive(:index_record)

    described_class.perform_now(plain_record, :index)
  end

  it 'raises on unknown actions' do
    expect do
      described_class.perform_now(record, :bogus)
    end.to raise_error(ArgumentError, 'Unknown action: bogus')
  end
end
