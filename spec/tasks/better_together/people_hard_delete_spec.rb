# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'better_together:people:hard_delete', type: :task do
  before do
    Rake.application&.clear
    Rake.application = Rake::Application.new
    load BetterTogether::Engine.root.join('lib/tasks/better_together/people_hard_delete.rake')
    Rake::Task.define_task(:environment)
  end

  after do
    Rake.application&.clear
    %w[PERSON_IDS DELETION_REQUEST_IDS PRESERVE_PERSON_IDS REVIEWED_BY_ID REASON WRITE_ENABLE].each do |key|
      ENV.delete(key)
    end
  end

  let(:task) { Rake::Task['better_together:people:hard_delete'] }
  let(:person) { create(:better_together_person) }
  let(:reviewer) { create(:better_together_person) }

  it 'prints a dry-run inventory by default' do
    allow(BetterTogether::PersonHardDeletionInventory).to receive(:call).with(person:).and_return(
      { deletion_mode: 'hard_delete', person_id: person.id, entries: [] }
    )
    ENV['PERSON_IDS'] = person.id

    expect { task.invoke }.to output(include('"mode": "dry_run"')).to_stdout
  end

  it 'executes the hard delete only when WRITE_ENABLE is true' do
    audit = instance_double(
      BetterTogether::PersonPurgeAudit,
      id: SecureRandom.uuid,
      status: 'completed',
      execution_snapshot: { 'deletion_mode' => 'hard_delete' }
    )
    allow(BetterTogether::PersonHardDeletionExecutor).to receive(:call).and_return(audit)
    ENV['PERSON_IDS'] = person.id
    ENV['REVIEWED_BY_ID'] = reviewer.id
    ENV['REASON'] = 'verified deletion'
    ENV['WRITE_ENABLE'] = 'true'

    expect { task.invoke }.to output(include('"mode": "hard_delete"')).to_stdout
    expect(BetterTogether::PersonHardDeletionExecutor).to have_received(:call).with(
      person:,
      person_deletion_request: nil,
      reviewed_by: reviewer,
      reason: 'verified deletion'
    )
  end
end
