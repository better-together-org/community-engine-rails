# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable RSpec/VerifiedDoubles
RSpec.describe BetterTogether::ContentSecurity::AttachmentEnrollment, type: :service do
  let(:record) { double('record') }
  let(:attachment) { double('attachment', attached?: true, blob_id: 'blob-123', blob: double('blob')) }
  let(:item) { instance_double(BetterTogether::ContentSecurity::Item, new_record?: true, id: 1, blob_id: nil, changed?: false) }

  before do
    allow(BetterTogether::ContentSecurity::Configuration).to receive_messages(enabled?: true, enabled_for_surface?: true)
    allow(record).to receive(:public_send).with(:avatar).and_return(attachment)
    allow(BetterTogether::ContentSecurity::Item).to receive(:for_attachment).and_return(double('scope', first_or_initialize: item))
    allow(item).to receive(:assign_attributes)
    allow(item).to receive(:lifecycle_state=)
    allow(item).to receive(:aggregate_verdict=)
    allow(item).to receive(:scanned_at=)
    allow(item).to receive(:released_at=)
    allow(item).to receive(:last_error_class=)
    allow(item).to receive(:last_error_summary=)
    allow(item).to receive(:save!)
    allow(BetterTogether::ContentSecurity::ScanAttachmentJob).to receive(:perform_later)
  end

  describe '.sync_attachment!' do
    subject(:sync) do
      described_class.sync_attachment!(record:, attachment_name: :avatar, surface: 'post_attachments')
    end

    context 'when content security is disabled' do
      before { allow(BetterTogether::ContentSecurity::Configuration).to receive(:enabled?).and_return(false) }

      it 'returns early without touching the attachment' do
        sync
        expect(record).not_to have_received(:public_send)
      end
    end

    context 'when the surface is not enabled' do
      before { allow(BetterTogether::ContentSecurity::Configuration).to receive(:enabled_for_surface?).and_return(false) }

      it 'returns early without touching the attachment' do
        sync
        expect(record).not_to have_received(:public_send)
      end
    end

    context 'when the attachment is not attached' do
      before { allow(attachment).to receive(:attached?).and_return(false) }

      it 'returns early without creating an item' do
        sync
        expect(BetterTogether::ContentSecurity::Item).not_to have_received(:for_attachment)
      end
    end

    context 'when the item is new (blob changed)' do
      it 'resets scan fields to pending_scan' do
        sync
        expect(item).to have_received(:lifecycle_state=).with('pending_scan')
        expect(item).to have_received(:aggregate_verdict=).with('pending_scan')
        expect(item).to have_received(:scanned_at=).with(nil)
      end

      it 'enqueues a ScanAttachmentJob' do
        sync
        expect(BetterTogether::ContentSecurity::ScanAttachmentJob).to have_received(:perform_later).with(item.id)
      end
    end

    context 'when the item already exists with the same blob (no change)' do
      before do
        allow(item).to receive_messages(new_record?: false, blob_id: 'blob-123')
      end

      it 'does not enqueue a ScanAttachmentJob' do
        sync
        expect(BetterTogether::ContentSecurity::ScanAttachmentJob).not_to have_received(:perform_later)
      end

      it 'does not reset lifecycle state' do
        sync
        expect(item).not_to have_received(:lifecycle_state=)
      end
    end
  end
end
# rubocop:enable RSpec/VerifiedDoubles
