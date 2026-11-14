# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonDataExport do
  subject(:export) { build(:better_together_person_data_export) }

  describe 'validations' do
    it 'is valid with required attributes' do
      expect(export).to be_valid
    end

    it 'requires format' do
      export.format = nil
      expect(export).not_to be_valid
    end

    it 'rejects unknown format' do
      export.format = 'csv'
      expect(export).not_to be_valid
    end

    it 'requires requested_at' do
      export.requested_at = nil
      expect(export).not_to be_valid
    end
  end

  describe 'STATUS_VALUES constant' do
    it 'defines pending, processing, completed, and failed' do
      expect(described_class::STATUS_VALUES.keys).to contain_exactly(:pending, :processing, :completed, :failed)
    end
  end

  describe '#filename' do
    it 'includes person_id and requested_at date' do
      export.requested_at = Time.zone.parse('2026-06-01 12:00:00')
      export.person_id = SecureRandom.uuid
      name = export.filename
      expect(name).to include(export.person_id)
      expect(name).to include('2026-06-01')
      expect(name).to end_with('.json')
    end
  end

  describe '#mark_processing!' do
    it 'transitions status to processing and sets started_at' do
      record = create(:better_together_person_data_export)
      record.mark_processing!
      expect(record.reload.status).to eq('processing')
      expect(record.started_at).to be_present
    end
  end

  describe '#mark_completed!' do
    it 'transitions status to completed and sets completed_at' do
      record = create(:better_together_person_data_export)
      record.mark_completed!
      expect(record.reload.status).to eq('completed')
      expect(record.completed_at).to be_present
    end
  end

  describe '#mark_failed!' do
    it 'transitions status to failed with an error message' do
      record = create(:better_together_person_data_export)
      record.mark_failed!('Disk full')
      expect(record.reload.status).to eq('failed')
      expect(record.error_message).to eq('Disk full')
    end
  end

  describe '.active scope' do
    it 'returns pending and processing exports' do
      pending_rec = create(:better_together_person_data_export, status: 'pending')
      completed_rec = create(:better_together_person_data_export, :completed)
      expect(described_class.active).to include(pending_rec)
      expect(described_class.active).not_to include(completed_rec)
    end
  end
end
