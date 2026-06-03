# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::UploadPolicy do
  let(:creator_user) { create(:better_together_user, :confirmed) }
  let(:other_user) { create(:better_together_user, :confirmed) }
  let(:upload) { create(:better_together_upload, creator: creator_user.person, privacy: 'private') }

  before do
    upload.file.attach(io: StringIO.new('download body'), filename: 'download.txt', content_type: 'text/plain')
    upload.save!
  end

  describe '#download?' do
    it 'blocks the creator while the file is still pending review' do
      expect(described_class.new(creator_user, upload).download?).to be(false)
    end

    it 'allows the creator after an explicit private release' do
      upload.file_content_security_subject.update!(
        lifecycle_state: 'approved_private',
        aggregate_verdict: 'clean',
        current_visibility_state: 'private',
        current_ai_ingestion_state: 'eligible',
        released_at: Time.current
      )

      expect(described_class.new(creator_user, upload).download?).to be(true)
    end

    it 'allows public downloads only after explicit public release' do
      public_upload = create(:better_together_upload, creator: creator_user.person, privacy: 'public')
      public_upload.file.attach(io: StringIO.new('public body'), filename: 'public.txt', content_type: 'text/plain')
      public_upload.save!

      expect(described_class.new(other_user, public_upload).download?).to be(false)

      public_upload.file_content_security_subject.update!(
        lifecycle_state: 'approved_public',
        aggregate_verdict: 'clean',
        current_visibility_state: 'public',
        current_ai_ingestion_state: 'eligible',
        released_at: Time.current
      )

      expect(described_class.new(other_user, public_upload).download?).to be(true)
    end
  end
end
