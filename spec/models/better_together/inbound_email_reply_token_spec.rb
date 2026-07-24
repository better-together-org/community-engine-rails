# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::InboundEmailReplyToken do
  let(:person) { create(:better_together_person) }
  let(:post) { create(:better_together_post) }

  describe '.issue!' do
    it 'generates a unique opaque token' do
      token = described_class.issue!(recipient: person, repliable: post, notification_type: 'comment_added')
      expect(token.token).to be_present
    end

    it 'sets an expiry in the future' do
      token = described_class.issue!(recipient: person, repliable: post, notification_type: 'comment_added')
      expect(token.expires_at).to be > Time.current
    end

    it 'is usable immediately after issuance' do
      token = described_class.issue!(recipient: person, repliable: post, notification_type: 'comment_added')
      expect(token).to be_usable
    end
  end

  describe '#usable?' do
    it 'is false once consumed' do
      token = described_class.issue!(recipient: person, repliable: post, notification_type: 'comment_added')
      token.consume!
      expect(token).not_to be_usable
      expect(token).to be_consumed
    end

    it 'is false once expired' do
      token = described_class.issue!(recipient: person, repliable: post, notification_type: 'comment_added')
      token.update!(expires_at: 1.minute.ago)
      expect(token).not_to be_usable
      expect(token).to be_expired
    end
  end

  describe '.active scope' do
    it 'excludes consumed tokens' do
      token = described_class.issue!(recipient: person, repliable: post, notification_type: 'comment_added')
      token.consume!
      expect(described_class.active).not_to include(token)
    end

    it 'excludes expired tokens' do
      token = described_class.issue!(recipient: person, repliable: post, notification_type: 'comment_added')
      token.update!(expires_at: 1.minute.ago)
      expect(described_class.active).not_to include(token)
    end

    it 'includes unconsumed, unexpired tokens' do
      token = described_class.issue!(recipient: person, repliable: post, notification_type: 'comment_added')
      expect(described_class.active).to include(token)
    end
  end

  describe '#reply_address' do
    it 'builds a reply+<token>@<domain> address' do
      token = described_class.issue!(recipient: person, repliable: post, notification_type: 'comment_added')
      expect(token.reply_address('example.test')).to eq("reply+#{token.token}@example.test")
    end
  end
end
