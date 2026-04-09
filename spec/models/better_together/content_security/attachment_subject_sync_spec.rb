# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::AttachmentSubjectSync do
  let(:upload) { create(:better_together_upload) }

  it 'creates a held subject record for newly attached upload files' do
    upload.file.attach(io: StringIO.new('first file'), filename: 'first.txt', content_type: 'text/plain')
    upload.save!

    subject = upload.reload.file_content_security_subject

    expect(subject).to be_present
    expect(subject.active_storage_blob).to eq(upload.file.blob)
    expect(subject.lifecycle_state).to eq('pending_scan')
    expect(subject.aggregate_verdict).to eq('review_required')
    expect(subject.current_visibility_state).to eq('private')
    expect(subject.current_ai_ingestion_state).to eq('pending_review')
  end

  it 're-holds the subject when a new blob replaces a previously released file' do
    upload.file.attach(io: StringIO.new('old file'), filename: 'old.txt', content_type: 'text/plain')
    upload.save!
    upload.file_content_security_subject.update!(
      lifecycle_state: 'approved_public',
      aggregate_verdict: 'clean',
      current_visibility_state: 'public',
      current_ai_ingestion_state: 'eligible',
      released_at: Time.current
    )

    upload.reload.file.attach(io: StringIO.new('new file'), filename: 'new.txt', content_type: 'text/plain')
    upload.save!

    subject = upload.reload.file_content_security_subject

    expect(subject.active_storage_blob).to eq(upload.file.blob)
    expect(subject.lifecycle_state).to eq('pending_scan')
    expect(subject.aggregate_verdict).to eq('review_required')
    expect(subject.current_visibility_state).to eq('private')
    expect(subject.current_ai_ingestion_state).to eq('pending_review')
    expect(subject.released_at).to be_nil
  end
end
