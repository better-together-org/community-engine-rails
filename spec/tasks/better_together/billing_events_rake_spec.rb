# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'better_together:billing event tasks', type: :task do
  include ActiveJob::TestHelper

  include_context 'with clean billing processors'

  before do
    Rake.application&.clear
    Rake.application = Rake::Application.new
    load BetterTogether::Engine.root.join('lib/tasks/better_together/billing_events.rake')
    Rake::Task.define_task(:environment)
    BetterTogether::Billing.register_processor(:fake, -> { BetterTogether::Billing::FakeAdapter.new })
  end

  after do
    Rake.application&.clear
    %w[APPLY OPERATOR ALL].each { |key| ENV.delete(key) }
  end

  let!(:host_platform) { configure_host_platform }
  let(:operator) { find_or_create_test_user("rake-op-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager).person }
  let!(:failed) do
    create(:better_together_billing_event, processing_status: 'failed', attempt_count: 2,
                                           payload: { 'id' => 'e', 'type' => 't', 'secret' => 'do-not-print' })
  end
  let!(:dead) do
    create(:better_together_billing_event, processing_status: 'dead_lettered', dead_lettered_at: 1.hour.ago,
                                           dead_letter_reason: 'retries_exhausted')
  end
  let!(:fine) { create(:better_together_billing_event, processing_status: 'processed') }

  def run_task(name, *)
    task = Rake::Task["better_together:billing:#{name}"]
    task.reenable
    task.invoke(*)
  end

  describe 'list_events' do
    it 'lists failed and dead-lettered events, not the others, and never the payload' do
      output = capture_stdout { run_task('list_events') }

      expect(output).to include(failed.id, dead.id)
      expect(output).not_to include(fine.id)
      expect(output).not_to include('do-not-print')
    end

    it 'filters by state' do
      output = capture_stdout { run_task('list_events', 'dead_lettered') }

      expect(output).to include(dead.id)
      expect(output).not_to include(failed.id)
    end

    it 'refuses a state it does not know' do
      expect { run_task('list_events', 'nonsense') }.to raise_error(ArgumentError, /State must be/)
    end

    it 'says so when there is nothing' do
      BetterTogether::Billing::Event.where(id: [failed.id, dead.id]).delete_all

      expect(capture_stdout { run_task('list_events') }).to include('No failed or dead-lettered billing events.')
    end
  end

  describe 'show_event' do
    it 'prints the state and history without the payload' do
      output = capture_stdout { run_task('show_event', dead.id) }

      expect(output).to include(dead.event_id, 'retries_exhausted', 'replayable: true')
      expect(output).not_to include('do-not-print')
    end
  end

  describe 'replay_event' do
    it 'changes nothing without APPLY' do
      output = capture_stdout { run_task('replay_event', failed.id) }

      expect(output).to include('would replay', 'Dry run')
      expect(failed.reload.processing_status).to eq('failed')
      expect(replay_jobs).to be_empty
    end

    it 'replays one event with APPLY and an operator' do
      ENV['APPLY'] = '1'
      ENV['OPERATOR'] = operator.id

      expect(capture_stdout { run_task('replay_event', dead.id) }).to include("#{dead.id}  replayed")
      expect(dead.reload).to have_attributes(processing_status: 'replayed', last_replay_requested_by_id: operator.id)
      expect(replay_jobs.size).to eq(1)
    end

    it 'replays every failed and dead-lettered event with ALL, and only those' do
      ENV['APPLY'] = '1'
      ENV['OPERATOR'] = operator.id
      ENV['ALL'] = '1'

      run_task('replay_event')

      expect([failed, dead].map { |event| event.reload.processing_status }).to all(eq('replayed'))
      expect(fine.reload.processing_status).to eq('processed')
      expect(replay_jobs.size).to eq(2)
    end

    it 'running it twice with APPLY queues the event once' do
      ENV['APPLY'] = '1'
      ENV['OPERATOR'] = operator.id

      run_task('replay_event', dead.id)
      output = capture_stdout { run_task('replay_event', dead.id) }

      expect(output).to include('refused (not_replayable)')
      expect(replay_jobs.size).to eq(1)
    end

    it 'refuses to apply without an operator or with someone who cannot manage the host' do
      ENV['APPLY'] = '1'
      expect { run_task('replay_event', dead.id) }.to raise_error(ArgumentError, /OPERATOR/)

      ENV['OPERATOR'] = create(:better_together_person).id
      expect { run_task('replay_event', dead.id) }.to raise_error(ArgumentError, /manage the host/)
      expect(dead.reload.processing_status).to eq('dead_lettered')
    end

    it 'asks for an id or ALL' do
      expect { run_task('replay_event') }.to raise_error(SystemExit)
    end
  end

  def replay_jobs = enqueued_jobs.select { |job| job['job_class'] == 'BetterTogether::Billing::ProcessBillingEventJob' }

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
