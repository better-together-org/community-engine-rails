# frozen_string_literal: true

require 'rails_helper'

# The readiness checklist asks whether a worker is taking billing jobs, and Enablement says why billing is off.
RSpec.describe BetterTogether::Billing::Readiness do
  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'

  let(:queue) { BetterTogether::Billing::ApplicationJob.new.queue_name.to_s }

  def worker_check = described_class.call(host_platform).checks.find { |check| check.key == :worker }

  def stub_processes(*queue_lists)
    processes = queue_lists.map { |queues| { 'queues' => queues } }
    allow(Sidekiq::ProcessSet).to receive(:new).with(false).and_return(processes)
  end

  context 'when the queue adapter is not Sidekiq' do
    it 'cannot check and does not block' do
      expect(worker_check).to have_attributes(ok: true, detail: [])
    end
  end

  context 'with Sidekiq' do
    before { allow(ActiveJob::Base).to receive(:queue_adapter_name).and_return('sidekiq') }

    it 'is not ready when no process serves the billing queue', :aggregate_failures do
      stub_processes(%w[default mailers])

      expect(worker_check).to have_attributes(ok: false, detail: [:no_worker])
      expect(described_class.call(host_platform)).not_to be_ready
    end

    it 'is not ready when jobs wait and are not taken' do
      stub_processes([queue])
      allow(Sidekiq::Queue).to receive(:new).with(queue).and_return(instance_double(Sidekiq::Queue, latency: 10.minutes.to_f))

      expect(worker_check).to have_attributes(ok: false, detail: [:backlog])
    end

    it 'is fine when a process serves the queue and nothing is stuck' do
      stub_processes([queue])
      allow(Sidekiq::Queue).to receive(:new).with(queue).and_return(instance_double(Sidekiq::Queue, latency: 2.0))

      expect(worker_check).to have_attributes(ok: true)
    end

    it 'says so when the queue cannot be reached' do
      allow(Sidekiq::ProcessSet).to receive(:new).and_raise(Errno::ECONNREFUSED)

      expect(worker_check).to have_attributes(ok: false, detail: [:unreachable])
    end
  end

  describe BetterTogether::Billing::Enablement do
    it 'names every step still missing, in order', :aggregate_failures do
      allow(BetterTogether::Billing::Configuration).to receive_messages(requested?: false, missing_keys: %w[PAY_BUSINESS_NAME],
                                                                        processors_for: [])

      problems = described_class.call(host_platform)

      expect(problems.map(&:key)).to eq(%i[flag identity method_enabled])
      expect(problems.find { |problem| problem.key == :identity }.detail).to eq(%w[PAY_BUSINESS_NAME])
    end
  end
end
