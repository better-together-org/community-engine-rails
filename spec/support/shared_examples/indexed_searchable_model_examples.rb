# frozen_string_literal: true

RSpec.shared_examples 'an indexed searchable model' do |factory_name|
  let(:record) { create(factory_name) }

  it 'is explicitly included in the indexed model registry' do
    expect(BetterTogether::Search::Registry.models).to include(described_class)
  end

  it 'enqueues the index job through the index callback hook' do
    expect do
      record.send(:enqueue_index_document)
    end.to have_enqueued_job(BetterTogether::ElasticsearchIndexJob).with(record, :index)
  end

  it 'enqueues the delete job through the delete callback hook' do
    expect do
      record.send(:enqueue_delete_document)
    end.to have_enqueued_job(BetterTogether::ElasticsearchIndexJob).with(record, :delete)
  end
end
