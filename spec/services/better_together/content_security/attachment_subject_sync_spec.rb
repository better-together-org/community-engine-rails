# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe BetterTogether::ContentSecurity::AttachmentSubjectSync, type: :service do
  let(:blob) { double('blob', id: 42) }
  let(:attachment) { double('attachment', attached?: true, blob:) }
  let(:record) { double('record', avatar: attachment) }
  let(:subject_record) do
    instance_double(BetterTogether::ContentSecurity::Subject,
                    new_record?: true,
                    active_storage_blob_id: nil,
                    changed?: true)
  end

  before do
    allow(record).to receive(:public_send).with('avatar').and_return(attachment)
    allow(BetterTogether::ContentSecurity::Subject).to receive(:find_or_initialize_by)
      .and_return(subject_record)
    allow(subject_record).to receive(:active_storage_blob=)
    allow(subject_record).to receive(:source_surface=)
    allow(subject_record).to receive(:storage_ref=)
    allow(subject_record).to receive(:reset_to_pending_review!)
    allow(subject_record).to receive(:save!)
  end

  describe '#call' do
    subject(:call) do
      described_class.new(record:, attachment_name: :avatar, source_surface: 'mail').call
    end

    context 'when the attachment is not attached' do
      before do
        allow(attachment).to receive(:attached?).and_return(false)
        allow(BetterTogether::ContentSecurity::Subject).to receive(:find_by).and_return(nil)
      end

      it 'calls destroy_subject! instead of syncing' do
        expect(BetterTogether::ContentSecurity::Subject).to receive(:find_by)
          .with(subject: record, attachment_name: 'avatar')
        call
      end

      it 'does not create or update a subject' do
        allow(BetterTogether::ContentSecurity::Subject).to receive(:find_by).and_return(nil)
        call
        expect(subject_record).not_to have_received(:save!)
      end
    end

    context 'when the attachment is attached and the subject is new' do
      it 'assigns the blob to the subject' do
        call
        expect(subject_record).to have_received(:active_storage_blob=).with(blob)
      end

      it 'assigns the source_surface' do
        call
        expect(subject_record).to have_received(:source_surface=).with('mail')
      end

      it 'assigns the storage_ref as an active_storage path' do
        call
        expect(subject_record).to have_received(:storage_ref=).with("active_storage/blob/#{blob.id}")
      end

      it 'resets the subject to pending review when blob changes' do
        call
        expect(subject_record).to have_received(:reset_to_pending_review!)
      end

      it 'saves the subject when changed' do
        call
        expect(subject_record).to have_received(:save!)
      end
    end

    context 'when the blob has not changed' do
      before do
        allow(subject_record).to receive_messages(new_record?: false, active_storage_blob_id: blob.id)
      end

      it 'does not reset to pending review' do
        call
        expect(subject_record).not_to have_received(:reset_to_pending_review!)
      end
    end

    context 'when the subject has no unsaved changes' do
      before { allow(subject_record).to receive(:changed?).and_return(false) }

      it 'does not call save!' do
        call
        expect(subject_record).not_to have_received(:save!)
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
