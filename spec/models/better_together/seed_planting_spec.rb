# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SeedPlanting do
  let(:person) { create(:better_together_person) }
  let(:seed) { create(:better_together_seed) }

  describe 'associations' do
    it { is_expected.to belong_to(:creator).class_name('BetterTogether::Person').optional }
    it { is_expected.to belong_to(:seed).class_name('BetterTogether::Seed').optional }

    it 'has planted_by alias for creator' do
      planting = described_class.new(creator: person)
      expect(planting.planted_by).to eq(person)
    end

    it 'sets creator through planted_by alias' do
      planting = described_class.new
      planting.planted_by = person
      expect(planting.creator).to eq(person)
    end
  end

  describe 'validations' do
    subject { build(:better_together_seed_planting, creator: person) }

    it { is_expected.to be_valid }
    it { is_expected.to validate_presence_of(:status) }

    it 'validates status values' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      # Test statuses that don't require completed_at
      valid_statuses = %w[pending in_progress]
      valid_statuses.each do |status|
        planting = build(:better_together_seed_planting,
                         creator: person, status: status)
        expect(planting).to be_valid, "#{status} should be valid"
      end

      # Test terminal statuses that require completed_at
      terminal_statuses = %w[completed failed cancelled]
      terminal_statuses.each do |status|
        planting = build(:better_together_seed_planting, creator: person, status: status, completed_at: Time.current)
        planting.error_message = 'Test error' if status == 'failed'
        expect(planting).to be_valid, "#{status} should be valid with completed_at"
      end

      # Test that enum raises error for invalid status
      expect do
        build(:better_together_seed_planting, creator: person, status: 'invalid_status')
      end.to raise_error(ArgumentError, "'invalid_status' is not a valid status")
    end
  end

  describe 'enums' do
    it 'defines status enum' do # rubocop:todo RSpec/ExampleLength
      expect(described_class.statuses).to eq({
                                               'pending' => 'pending',
                                               'in_progress' => 'in_progress',
                                               'completed' => 'completed',
                                               'failed' => 'failed',
                                               'cancelled' => 'cancelled'
                                             })
    end
  end

  describe 'status management' do
    let(:planting) { create(:better_together_seed_planting, creator: person) }

    describe '#mark_started!' do
      it 'updates status to in_progress' do
        planting.mark_started!
        expect(planting.reload.status).to eq('in_progress')
      end

      it 'updates started_at timestamp' do # rubocop:todo RSpec/MultipleExpectations
        expect(planting.started_at).to be_nil
        planting.mark_started!
        expect(planting.reload.started_at).to be_present
      end

      it 'updates metadata with started timestamp' do
        planting.mark_started!
        expect(planting.reload.metadata['started_at']).to be_present
      end
    end

    describe '#mark_completed!' do
      before { planting.mark_started! }

      it 'updates status to completed' do
        planting.mark_completed!
        expect(planting.reload.status).to eq('completed')
      end

      it 'updates completed_at timestamp' do # rubocop:todo RSpec/MultipleExpectations
        expect(planting.completed_at).to be_nil
        planting.mark_completed!
        expect(planting.reload.completed_at).to be_present
      end

      it 'stores result data when provided' do
        result_data = { records_created: 5 }
        planting.mark_completed!(result_data)
        expect(planting.reload.result).to eq(result_data.stringify_keys)
      end

      it 'calculates duration in metadata' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
        planting.mark_started!
        sleep(0.01) # Small delay to ensure measurable duration
        planting.mark_completed!
        duration = planting.reload.metadata['duration_seconds']
        expect(duration).to be_a(Numeric)
        expect(duration).to be >= 0
      end
    end

    describe '#mark_failed!' do
      before { planting.mark_started! }

      it 'updates status to failed' do
        error = StandardError.new('Test error')
        planting.mark_failed!(error)
        expect(planting.reload.status).to eq('failed')
      end

      it 'sets error_message' do
        error = StandardError.new('Test error')
        planting.mark_failed!(error)
        expect(planting.reload.error_message).to eq('Test error')
      end

      it 'updates completed_at timestamp' do # rubocop:todo RSpec/MultipleExpectations
        error = StandardError.new('Test error')
        expect(planting.completed_at).to be_nil
        planting.mark_failed!(error)
        expect(planting.reload.completed_at).to be_present
      end

      it 'stores error details when provided' do
        error = StandardError.new('Test error')
        error_details = { backtrace: ['line 1', 'line 2'] }
        planting.mark_failed!(error, error_details)

        metadata = planting.reload.metadata
        expect(metadata['error_details']['backtrace']).to eq(['line 1', 'line 2'])
      end
    end

    describe '#mark_cancelled!' do
      before { planting.mark_started! }

      it 'updates status to cancelled' do
        planting.mark_cancelled!
        expect(planting.reload.status).to eq('cancelled')
      end

      it 'stores cancellation reason when provided' do
        planting.mark_cancelled!('User requested cancellation')
        expect(planting.reload.metadata['cancellation_reason']).to eq('User requested cancellation')
      end
    end
  end

  describe 'metadata handling' do
    let(:planting) { create(:better_together_seed_planting, creator: person) }

    it 'stores metadata as JSONB' do
      metadata = { source: 'test', options: { validate: true } }
      planting.update!(metadata: metadata)
      expect(planting.reload.metadata).to eq(metadata.deep_stringify_keys)
    end

    it 'handles nested metadata' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      nested_data = {
        import_options: {
          track_progress: true,
          validation_level: 'strict'
        },
        file_info: {
          size: 1024,
          checksum: 'abc123'
        }
      }

      planting.update!(metadata: nested_data)
      reloaded = planting.reload.metadata

      expect(reloaded['import_options']['track_progress']).to be true
      expect(reloaded['file_info']['size']).to eq(1024)
    end
  end

  describe 'scopes' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    let!(:pending_planting) { create(:better_together_seed_planting, creator: person, status: 'pending') }
    let!(:in_progress_planting) { create(:better_together_seed_planting, creator: person, status: 'in_progress') }
    let!(:completed_planting) { create(:better_together_seed_planting, :completed, creator: person) }
    let!(:failed_planting) { create(:better_together_seed_planting, :failed, creator: person) }

    it 'filters by status' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      expect(described_class.pending).to include(pending_planting)
      expect(described_class.pending).not_to include(completed_planting)

      expect(described_class.in_progress).to include(in_progress_planting)
      expect(described_class.in_progress).not_to include(pending_planting)

      expect(described_class.completed).to include(completed_planting)
      expect(described_class.completed).not_to include(pending_planting)

      expect(described_class.failed).to include(failed_planting)
      expect(described_class.failed).not_to include(pending_planting)
    end

    it 'orders by created_at desc' do
      plantings = described_class.recent
      expect(plantings.first).to eq(failed_planting) # Created last
    end
  end

  describe 'factory' do
    it 'creates valid seed planting' do
      planting = build(:better_together_seed_planting, creator: person)
      expect(planting).to be_valid
    end

    it 'creates with seed association' do
      planting = create(:better_together_seed_planting, creator: person, seed: seed)
      expect(planting.seed).to eq(seed)
    end
  end
end
