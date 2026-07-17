# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Metrics::RichTextLink do
  describe 'platform derivation (Metrics::PlatformScoped)' do
    let(:federated_platform) { create(:better_together_platform, :public, host: false) }
    let(:sender) { create(:better_together_person) }
    let(:conversation) do
      BetterTogether::Conversation.create!(creator: sender, platform: federated_platform, title: '',
                                           participant_ids: [sender.id])
    end
    let(:message) do
      BetterTogether::Message.create!(conversation: conversation, sender: sender, platform: federated_platform,
                                      content: 'See https://example.com for details')
    end
    let(:rich_text) do
      ActionText::RichText.find_by!(record_type: 'BetterTogether::Message', record_id: message.id, name: 'content')
    end
    let(:link) { create(:content_link, url: 'https://example.com') }

    it "derives platform_id from rich_text_record's own platform" do
      rich_text_link = described_class.create!(
        link: link,
        rich_text: rich_text,
        rich_text_record: message,
        position: 0
      )

      expect(rich_text_link.platform).to eq(federated_platform)
    end

    it 'does not override an explicitly-set platform' do
      other_platform = create(:better_together_platform, :public, host: false)
      rich_text_link = described_class.create!(
        link: link,
        rich_text: rich_text,
        rich_text_record: message,
        position: 0,
        platform: other_platform
      )

      expect(rich_text_link.platform).to eq(other_platform)
    end
  end
end
