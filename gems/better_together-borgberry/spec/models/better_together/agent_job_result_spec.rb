# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::AgentJobResult do
  subject(:result) { build(:better_together_agent_job_result) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:job_id) }
    it { is_expected.to validate_uniqueness_of(:job_id) }
    it { is_expected.to validate_presence_of(:job_type) }
    it { is_expected.to validate_presence_of(:source_system) }

    it 'validates status is within allowed values' do
      described_class::JOB_STATUSES.each do |s|
        result.status = s
        expect(result).to be_valid
      end
    end

    it 'rejects an unknown status' do
      result.status = 'unknown_state'
      expect(result).not_to be_valid
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:fleet_node).optional }
    it { is_expected.to belong_to(:submitter).optional }
  end

  describe '#duration_s' do
    context 'when both started_at and completed_at are set' do
      it 'returns the elapsed seconds as a float' do
        travel_to(Time.current) do
          job = create(:better_together_agent_job_result, :completed,
                       started_at: 5.seconds.ago, completed_at: Time.current)
          expect(job.duration_s).to be_within(0.1).of(5.0)
        end
      end
    end

    context 'when started_at is nil' do
      it 'returns nil' do
        job = create(:better_together_agent_job_result, started_at: nil, completed_at: Time.current)
        expect(job.duration_s).to be_nil
      end
    end

    context 'when completed_at is nil' do
      it 'returns nil' do
        job = create(:better_together_agent_job_result, :running, completed_at: nil)
        expect(job.duration_s).to be_nil
      end
    end
  end

  describe '#success?' do
    it 'returns true for completed jobs' do
      result.status = 'completed'
      expect(result.success?).to be true
    end

    it 'returns false for failed jobs' do
      result.status = 'failed'
      expect(result.success?).to be false
    end

    it 'returns false for pending jobs' do
      result.status = 'pending'
      expect(result.success?).to be false
    end

    it 'returns false for running jobs' do
      result.status = 'running'
      expect(result.success?).to be false
    end
  end

  describe '#to_s' do
    it 'formats as job_type:job_id' do
      result.job_type = 'embedding'
      result.job_id = 'borgberry-job-42'
      expect(result.to_s).to eq('embedding:borgberry-job-42')
    end
  end

  describe 'scopes' do
    let!(:completed_job) { create(:better_together_agent_job_result, :completed, job_id: 'done-1') }
    let!(:failed_job) { create(:better_together_agent_job_result, :failed, job_id: 'fail-1') }
    let!(:pending_job) { create(:better_together_agent_job_result, job_id: 'pend-1') }

    it '.completed returns only completed jobs' do
      expect(described_class.completed).to include(completed_job)
      expect(described_class.completed).not_to include(failed_job, pending_job)
    end

    it '.failed returns only failed jobs' do
      expect(described_class.failed).to include(failed_job)
      expect(described_class.failed).not_to include(completed_job, pending_job)
    end
  end

  describe 'polymorphic submitter' do
    it 'accepts a Person as submitter' do
      person = create(:better_together_person)
      job = create(:better_together_agent_job_result, submitter: person)
      expect(job.reload.submitter).to eq(person)
    end
  end
end
