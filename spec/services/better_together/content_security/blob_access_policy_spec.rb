# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ContentSecurity::BlobAccessPolicy, type: :service do
  let(:upload) { create(:better_together_upload) }

  before do
    upload.file.attach(io: StringIO.new('proxy file'), filename: 'proxy.txt', content_type: 'text/plain')
    upload.save!
  end

  it 'blocks public proxy access while the blob is still held' do
    expect(described_class.public_proxy_allowed?(upload.file.blob)).to be(false)
  end

  it 'allows public proxy access after explicit release' do
    upload.file_content_security_subject.update!(
      lifecycle_state: 'approved_public',
      aggregate_verdict: 'clean',
      current_visibility_state: 'public',
      current_ai_ingestion_state: 'eligible',
      released_at: Time.current
    )

    expect(described_class.public_proxy_allowed?(upload.file.blob)).to be(true)
  end
end
