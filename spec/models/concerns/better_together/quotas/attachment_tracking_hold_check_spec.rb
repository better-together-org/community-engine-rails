# frozen_string_literal: true

require 'rails_helper'

# A direct upload holds the size the client declared; attaching a bigger blob is checked for the difference.
RSpec.describe BetterTogether::Quotas::AttachmentTracking do
  let(:host) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }
  let(:person) { create(:better_together_person) }
  let(:blob) do
    ActiveStorage::Blob.create_before_direct_upload!(filename: 'a.png', byte_size: 5_000, checksum: Digest::MD5.base64digest('x'),
                                                     content_type: 'image/png')
  end

  def hold(amount)
    BetterTogether::Quotas.reserve!(type: 'media_storage', owner: host, amount:, idempotency_key: "hold:#{SecureRandom.uuid}",
                                    subject: blob, enforce: false)
  end

  # Other examples commit usage against the host's quota (it is shared and not rolled back), so room is
  # measured from what is already used, not from zero.
  def limit_to_headroom(amount)
    used = BetterTogether::Quotas.usage_for(type: 'media_storage', owner: host)[:used]
    BetterTogether::Quota.find_by!(owner: host, quota_type: 'media_storage').update!(limit: used + amount)
  end

  def attachment = ActiveStorage::Attachment.new(record: person, name: 'profile_image', blob:)

  before do
    BetterTogether::Quotas.sync_limit!(type: 'media_storage', owner: host)
    host.set_quota_enforcement!('media_storage', 'hard')
    limit_to_headroom(10_000)
  end

  it 'allows a blob that matches its hold' do
    hold(5_000)

    expect(attachment).to be_valid
  end

  it 'allows a blob with no hold (a server-side attach)' do
    expect(attachment).to be_valid
  end

  it 'refuses a blob bigger than its hold when the difference does not fit' do
    hold(100)
    limit_to_headroom(1_000)

    expect(attachment).not_to be_valid
  end

  it 'allows a blob bigger than its hold when the difference fits' do
    hold(100)

    expect(attachment).to be_valid
  end

  it 'lets the attach through if the check itself fails, and records it' do
    hold(100)
    allow(BetterTogether::Quotas).to receive(:check!).and_raise(StandardError, 'quota bug')
    allow(BetterTogether::Quotas).to receive(:record_failure)

    expect(attachment).to be_valid
    expect(BetterTogether::Quotas).to have_received(:record_failure)
  end
end
