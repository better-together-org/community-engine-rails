# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::AttachmentHook do
  let(:config) { BetterTogether::ContentSecurity::Configuration }
  let(:item_class) { BetterTogether::ContentSecurity::Item }
  let(:community) { create(:better_together_community) }

  def new_blob(name = 'a.txt')
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new(SecureRandom.hex(8)), filename: name,
                                           content_type: 'text/plain')
  end

  def attach(blob, record = community)
    ActiveStorage::Attachment.create!(name: 'profile_image', record: record.reload, blob:)
  end

  context 'when the attachments surface is enabled' do
    before do
      allow(config).to receive_messages(enabled?: true)
      allow(config).to receive(:enabled_for_surface?) { |surface| surface.to_s == 'attachments' }
      allow(BetterTogether::ContentSecurity::ScanAttachmentJob).to receive(:perform_later)
    end

    it 'enrolls an attachment on a model that does not declare scans_attachment' do
      blob = new_blob
      expect { attach(blob) }.to change { item_class.where(blob_id: blob.id).count }.by(1)
      item = item_class.find_by(blob_id: blob.id)
      expect(item).to have_attributes(source_surface: 'attachments', lifecycle_state: 'pending_scan')
      expect(BetterTogether::ContentSecurity::ScanAttachmentJob).to have_received(:perform_later).with(item.id)
    end

    it 'gives every blob in a many slot its own item' do
      first = new_blob('one.txt')
      second = new_blob('two.txt')
      attach(first)
      attach(second)
      expect(item_class.where(blob_id: [first.id, second.id]).count).to eq(2)
    end

    it 'does not enroll variant records' do
      blob = new_blob
      variant_record = ActiveStorage::VariantRecord.create!(blob: new_blob('src.txt'), variation_digest: 'abc')
      expect { ActiveStorage::Attachment.create!(name: 'image', record: variant_record, blob:) }
        .not_to change(item_class, :count)
    end

    it 'withholds an unscanned blob and releases it once clean' do
      blob = new_blob
      attach(blob)
      policy = BetterTogether::ContentSecurity::BlobAccessPolicy
      expect(policy.public_proxy_allowed?(blob)).to be false

      item_class.find_by(blob_id: blob.id).update!(lifecycle_state: 'clean', aggregate_verdict: 'clean')
      expect(policy.public_proxy_allowed?(blob)).to be true
    end

    it 'reports and does not raise when enrollment fails' do
      allow(BetterTogether::ContentSecurity::AttachmentEnrollment).to receive(:enroll_attachment!).and_raise('boom')
      allow(BetterTogether).to receive(:report_error)
      expect { attach(new_blob) }.not_to raise_error
      expect(BetterTogether).to have_received(:report_error)
        .with(an_instance_of(RuntimeError), context: hash_including(check: 'content_security_enrollment'))
    end
  end

  context 'when the attachments surface is disabled' do
    before do
      allow(config).to receive_messages(enabled?: true, enabled_for_surface?: false)
    end

    it 'does not enroll and does not withhold the blob' do
      blob = new_blob
      expect { attach(blob) }.not_to change(item_class, :count)
      expect(BetterTogether::ContentSecurity::BlobAccessPolicy.public_proxy_allowed?(blob)).to be true
    end
  end

  context 'when scanning is disabled' do
    before { allow(config).to receive(:enabled?).and_return(false) }

    it 'does not enroll' do
      expect { attach(new_blob) }.not_to change(item_class, :count)
    end
  end

  context 'with the backfill' do
    let!(:blob_before) do
      allow(config).to receive(:enabled?).and_return(false)
      blob = new_blob
      attach(blob)
      blob
    end

    before do
      allow(config).to receive_messages(enabled?: true)
      allow(config).to receive(:enabled_for_surface?) { |surface| surface.to_s == 'attachments' }
      allow(BetterTogether::ContentSecurity::ScanAttachmentJob).to receive(:perform_later)
    end

    it 'enrolls attachments that predate the surface' do
      expect { BetterTogether::ContentSecurity::AttachmentBackfill.call }
        .to change { item_class.where(blob_id: blob_before.id).count }.from(0).to(1)
    end
  end
end
