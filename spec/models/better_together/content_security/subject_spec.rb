# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::Subject do
  let(:person) { create(:better_together_person) }
  let(:blob) do
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new('test content'),
      filename: 'test.txt',
      content_type: 'text/plain'
    )
  end

  def build_subject(overrides = {})
    described_class.new({
      subject: person,
      attachment_name: 'file',
      source_surface: 'uploads',
      storage_ref: 'uploads/test_ref'
    }.merge(overrides))
  end

  describe 'validations' do
    it 'is valid with required attributes' do
      s = build_subject
      s.valid?
      expect(s.errors.full_messages).not_to include(match(/attachment_name|source_surface|storage_ref/))
    end

    it 'requires attachment_name' do
      s = build_subject(attachment_name: nil)
      expect(s).not_to be_valid
      expect(s.errors[:attachment_name]).to be_present
    end

    it 'requires source_surface' do
      s = build_subject(source_surface: nil)
      expect(s).not_to be_valid
      expect(s.errors[:source_surface]).to be_present
    end

    it 'requires storage_ref' do
      # Build without blob so ensure_storage_ref cannot auto-fill it
      s = described_class.new(
        subject: person,
        attachment_name: 'file',
        source_surface: 'uploads'
      )
      expect(s).not_to be_valid
      expect(s.errors[:storage_ref]).to be_present
    end
  end

  describe '#ensure_content_id callback' do
    it 'auto-generates content_id on create from subject type, id, and attachment_name' do
      s = build_subject
      s.save!
      expect(s.content_id).to include(person.id.to_s)
      expect(s.content_id).to include('file')
    end

    it 'does not overwrite a manually provided content_id' do
      s = build_subject
      s.content_id = 'manual_content_id'
      s.save!
      expect(s.reload.content_id).to eq('manual_content_id')
    end
  end

  describe '#ensure_storage_ref callback' do
    it 'auto-generates storage_ref from blob when blob is provided' do
      s = described_class.new(
        subject: person,
        attachment_name: 'file',
        source_surface: 'uploads',
        active_storage_blob: blob
      )
      s.valid?
      expect(s.storage_ref).to include(blob.id.to_s)
    end
  end

  describe '#released_for_human_access?' do
    it 'returns true when lifecycle_state is approved and verdict is clean' do
      s = build_subject
      s.lifecycle_state = 'approved_public'
      s.aggregate_verdict = 'clean'
      expect(s.released_for_human_access?).to be true
    end

    it 'returns false when lifecycle_state is pending_scan' do
      s = build_subject
      s.lifecycle_state = 'pending_scan'
      s.aggregate_verdict = 'review_required'
      expect(s.released_for_human_access?).to be false
    end

    it 'returns false when lifecycle_state is approved but verdict is review_required' do
      s = build_subject
      s.lifecycle_state = 'approved_public'
      s.aggregate_verdict = 'review_required'
      expect(s.released_for_human_access?).to be false
    end
  end

  describe '#held_for_review?' do
    it 'is the inverse of released_for_human_access?' do
      s = build_subject
      s.lifecycle_state = 'pending_scan'
      s.aggregate_verdict = 'review_required'
      expect(s.held_for_review?).to be true
      s.lifecycle_state = 'approved_public'
      s.aggregate_verdict = 'clean'
      expect(s.held_for_review?).to be false
    end
  end

  describe '#publicly_serving_allowed?' do
    it 'returns true when released and visibility is public' do
      s = build_subject
      s.lifecycle_state = 'approved_public'
      s.aggregate_verdict = 'clean'
      s.current_visibility_state = 'public'
      expect(s.publicly_serving_allowed?).to be true
    end

    it 'returns false when released but visibility is private' do
      s = build_subject
      s.lifecycle_state = 'approved_public'
      s.aggregate_verdict = 'clean'
      s.current_visibility_state = 'private'
      expect(s.publicly_serving_allowed?).to be false
    end

    it 'returns false when not released' do
      s = build_subject
      s.lifecycle_state = 'pending_scan'
      expect(s.publicly_serving_allowed?).to be false
    end
  end

  describe '#reset_to_pending_review!' do
    it 'resets lifecycle and verdict fields' do
      s = build_subject
      s.lifecycle_state = 'approved_public'
      s.aggregate_verdict = 'clean'
      s.current_visibility_state = 'public'
      s.current_ai_ingestion_state = 'eligible'
      s.reset_to_pending_review!
      expect(s.lifecycle_state).to eq('pending_scan')
      expect(s.aggregate_verdict).to eq('review_required')
      expect(s.current_visibility_state).to eq('private')
      expect(s.current_ai_ingestion_state).to eq('pending_review')
      expect(s.released_at).to be_nil
    end
  end

  describe '.for_blob scope' do
    it 'returns subjects associated with a given blob' do
      s = described_class.new(
        subject: person,
        attachment_name: 'file',
        source_surface: 'uploads',
        active_storage_blob: blob
      )
      s.save!
      expect(described_class.for_blob(blob)).to include(s)
    end

    it 'excludes subjects for other blobs' do
      s = build_subject
      s.save!
      other_blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('other'),
        filename: 'other.txt',
        content_type: 'text/plain'
      )
      expect(described_class.for_blob(other_blob)).not_to include(s)
    end
  end
end
