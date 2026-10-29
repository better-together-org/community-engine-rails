# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Quotas::AttachmentTracking do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  def attach_file(record, attachment_name, content: 'hello world')
    record.public_send(attachment_name).attach(
      io: StringIO.new(content), filename: 'test.txt', content_type: 'text/plain'
    )
  end

  describe 'settlement on attach, generic across attachment paths' do
    it 'settles media_storage for a brand-new Upload#file attachment' do
      creator = create(:better_together_person)
      upload = create(:better_together_upload, creator:)

      expect { attach_file(upload, :file) }.to change(BetterTogether::QuotaUsage, :count).by(1)

      usage = BetterTogether::QuotaUsage.last
      expect(usage.quota_type).to eq('media_storage')
      expect(usage.owner).to eq(creator)
      expect(usage.amount).to eq(upload.file.blob.byte_size)
      expect(usage.event).to eq('settle')
    end

    it 'settles media_storage for a Community#cover_image attachment, owner is the Community itself' do
      community = create(:better_together_community)

      expect { attach_file(community, :cover_image) }.to change(BetterTogether::QuotaUsage, :count).by(1)

      usage = BetterTogether::QuotaUsage.last
      expect(usage.owner).to eq(community)
    end

    it 'settles media_storage for a Trix-embedded rich text image, resolved through the ActionText hop' do
      creator = create(:better_together_person)
      upload = create(:better_together_upload, creator:)
      # ActionText parses <action-text-attachment> tags from the body HTML into real
      # ActiveStorage::Attachment rows on save; embeds.attach is not a real attach
      # path for rich text (it is populated by ActionText itself, not callable directly).
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new('fake image bytes'), filename: 'embedded.png', content_type: 'image/png'
      )
      embed_html = ActionText::Attachment.from_attachable(blob).to_html

      expect { upload.update!(description: embed_html) }.to change(BetterTogether::QuotaUsage, :count).by(1)

      usage = BetterTogether::QuotaUsage.last
      expect(usage.owner).to eq(creator)
      expect(usage.amount).to eq(blob.byte_size)
    end

    it 'is idempotent: re-attaching the exact same blob to the same attachment slot settles once per attach event' do
      creator = create(:better_together_person)
      upload = create(:better_together_upload, creator:)
      attach_file(upload, :file)

      expect(BetterTogether::QuotaUsage.where(subject: upload.file.attachment, event: 'settle').count).to eq(1)
    end
  end

  describe 'reversal on detach' do
    it 'writes a negative-amount reversing row owned by the original owner' do
      creator = create(:better_together_person)
      upload = create(:better_together_upload, creator:)
      attach_file(upload, :file)
      byte_size = upload.file.blob.byte_size

      expect { upload.file.detach }.to change(BetterTogether::QuotaUsage, :count).by(1)

      reversal = BetterTogether::QuotaUsage.where(event: 'reverse').last
      expect(reversal.amount).to eq(-byte_size)
      expect(reversal.owner).to eq(creator)
    end

    it 'reuses the settle row owner even if the owning record is destroyed in the same transaction' do
      creator = create(:better_together_person)
      upload = create(:better_together_upload, creator:)
      attach_file(upload, :file)
      upload.reload # the content-security after_commit hook may have bumped lock_version

      expect { upload.destroy! }.to change(BetterTogether::QuotaUsage, :count).by(1)

      reversal = BetterTogether::QuotaUsage.where(event: 'reverse').last
      expect(reversal.owner).to eq(creator)
    end
  end
end
