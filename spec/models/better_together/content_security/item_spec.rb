# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::Item do
  subject(:item) do
    described_class.new(
      blob: blob,
      attachable: upload,
      attachment_name: 'file',
      source_surface: 'uploads',
      lifecycle_state: 'pending_scan',
      aggregate_verdict: 'pending_scan'
    )
  end

  let(:upload) { create(:better_together_upload) }
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('test content'),
      filename: "test-#{SecureRandom.hex(4)}.txt",
      content_type: 'text/plain'
    )
  end

  describe 'associations' do
    it { is_expected.to belong_to(:blob).class_name('ActiveStorage::Blob') }
    it { is_expected.to belong_to(:attachable).without_validating_presence }
    it { is_expected.to belong_to(:safety_case).class_name('BetterTogether::Safety::Case').optional }
    it { is_expected.to have_many(:scan_events).class_name('BetterTogether::ContentSecurity::ScanEvent').dependent(:destroy) }
    it { is_expected.to have_many(:findings).class_name('BetterTogether::ContentSecurity::Finding').dependent(:destroy) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:attachment_name) }
    it { is_expected.to validate_presence_of(:source_surface) }
    it { is_expected.to validate_presence_of(:lifecycle_state) }
    it { is_expected.to validate_presence_of(:aggregate_verdict) }

    it 'is valid with required attributes' do
      expect(item).to be_valid
    end

    it 'rejects an unknown lifecycle_state' do
      expect { item.lifecycle_state = 'unknown' }.to raise_error(ArgumentError)
    end

    it 'rejects an unknown aggregate_verdict' do
      expect { item.aggregate_verdict = 'unknown' }.to raise_error(ArgumentError)
    end
  end

  describe 'enums' do
    describe 'lifecycle_state' do
      it 'supports all expected states' do
        %w[pending_scan clean review_required quarantined blocked override_released].each do |state|
          item.lifecycle_state = state
          expect(item.lifecycle_state).to eq(state)
        end
      end
    end

    describe 'aggregate_verdict' do
      it 'supports all expected verdicts' do
        %w[pending_scan clean review_required quarantined blocked override_released].each do |verdict|
          item.aggregate_verdict = verdict
          expect(item.aggregate_verdict).to eq(verdict)
        end
      end
    end
  end

  describe '.for_attachment' do
    before { item.save! }

    it 'returns items matching the attachable and attachment name' do
      found = described_class.for_attachment(upload, 'file')
      expect(found).to include(item)
    end

    it 'returns no items for a different attachment name' do
      found = described_class.for_attachment(upload, 'avatar')
      expect(found).not_to include(item)
    end

    it 'returns no items for a different attachable' do
      other_upload = create(:better_together_upload)
      found = described_class.for_attachment(other_upload, 'file')
      expect(found).not_to include(item)
    end
  end

  describe '#releasable?' do
    it 'returns true when lifecycle_state is clean' do
      item.lifecycle_state = 'clean'
      expect(item.releasable?).to be true
    end

    it 'returns true when lifecycle_state is override_released' do
      item.lifecycle_state = 'override_released'
      expect(item.releasable?).to be true
    end

    it 'returns false when lifecycle_state is pending_scan' do
      item.lifecycle_state = 'pending_scan'
      expect(item.releasable?).to be false
    end

    it 'returns false when lifecycle_state is quarantined' do
      item.lifecycle_state = 'quarantined'
      expect(item.releasable?).to be false
    end

    it 'returns false when lifecycle_state is blocked' do
      item.lifecycle_state = 'blocked'
      expect(item.releasable?).to be false
    end
  end

  describe '#released_for_human_access?' do
    it 'is an alias for releasable?' do
      item.lifecycle_state = 'clean'
      expect(item.released_for_human_access?).to eq(item.releasable?)
    end
  end
end
