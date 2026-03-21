# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'better_together:search rake tasks', type: :task do
  before do
    Rake.application&.clear
    Rake.application = Rake::Application.new
    load BetterTogether::Engine.root.join('lib/tasks/search.rake')
    Rake::Task.define_task(:environment)
  end

  after do
    Rake.application&.clear
  end

  let(:backend) { instance_double(BetterTogether::Search::ElasticsearchBackend, backend_key: :elasticsearch) }
  let(:page_entry) { BetterTogether::Search::Registry::Entry.new(model_name: 'BetterTogether::Page', global_search: true) }
  let(:post_entry) { BetterTogether::Search::Registry::Entry.new(model_name: 'BetterTogether::Post', global_search: true) }

  before do
    allow(BetterTogether::Search).to receive(:backend).and_return(backend)
    allow(BetterTogether::Search::Registry).to receive(:entries).and_return([page_entry, post_entry])
    allow(BetterTogether::Search::Registry).to receive(:unmanaged_searchable_models).and_return([])
    allow(BetterTogether::Page).to receive(:count).and_return(2)
    allow(BetterTogether::Post).to receive(:count).and_return(1)
  end

  it 'reindexes all registry entries' do
    task = Rake::Task['better_together:search:reindex_all']

    expect(backend).to receive(:ensure_index).with(page_entry)
    expect(backend).to receive(:import_model).with(page_entry, force: true)
    expect(backend).to receive(:refresh_index).with(page_entry)
    expect(backend).to receive(:ensure_index).with(post_entry)
    expect(backend).to receive(:import_model).with(post_entry, force: true)
    expect(backend).to receive(:refresh_index).with(post_entry)

    task.invoke
  end

  it 'prints JSON for audit output' do
    task = Rake::Task['better_together:search:audit']
    audit = BetterTogether::Search::AuditService::Result.new(
      backend: :elasticsearch,
      configured: true,
      available: true,
      status: :ok,
      generated_at: Time.current,
      entries: [],
      unmanaged_model_names: []
    )
    allow(BetterTogether::Search::AuditService).to receive(:new).and_return(instance_double(
      BetterTogether::Search::AuditService,
      call: audit
    ))
    ENV['FORMAT'] = 'json'

    expect { task.invoke }.to output(include('"backend": "elasticsearch"')).to_stdout
  ensure
    ENV.delete('FORMAT')
  end
end
