# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::MessageRequest do # rubocop:todo RSpec/MultipleMemoizedHelpers
  let(:sender)    { create(:better_together_person) }
  let(:recipient) { create(:better_together_person) }
  let(:platform)  { create(:better_together_platform) }

  describe 'validations' do
    it 'is valid with all required attributes' do
      req = described_class.new(sender: sender, recipient: recipient, platform: platform,
                                note: 'Hello!')
      expect(req).to be_valid
    end

    it 'requires a note' do
      req = described_class.new(sender: sender, recipient: recipient, platform: platform)
      expect(req).not_to be_valid
      expect(req.errors[:note]).to be_present
    end

    it 'enforces note length limit of 1000' do
      req = described_class.new(sender: sender, recipient: recipient, platform: platform,
                                note: 'x' * 1001)
      expect(req).not_to be_valid
    end

    it 'is invalid when sender and recipient are the same' do
      req = described_class.new(sender: sender, recipient: sender, platform: platform,
                                note: 'Hello!')
      expect(req).not_to be_valid
      expect(req.errors[:recipient_id]).to be_present
    end

    it 'prevents duplicate pending requests from the same sender to the same recipient' do
      create(:better_together_message_request, sender: sender, recipient: recipient,
                                               platform: platform)
      duplicate = described_class.new(sender: sender, recipient: recipient, platform: platform,
                                      note: 'Another note')
      expect(duplicate).not_to be_valid
    end
  end

  describe '#accept!' do
    let(:request) do
      create(:better_together_message_request, sender: sender, recipient: recipient,
                                               platform: platform)
    end

    it 'marks the request as accepted' do
      request.accept!
      expect(request.reload).to be_accepted
      expect(request.responded_at).to be_present
    end

    it 'creates a PersonMessagingGrant allowing the sender to message the recipient' do
      request.accept!
      expect(
        BetterTogether::PersonMessagingGrant.exists?(grantor: recipient, grantee: sender)
      ).to be(true)
    end

    it 'creates a Conversation between sender and recipient' do
      expect { request.accept! }.to change(BetterTogether::Conversation, :count).by(1)
    end

    it 'adds the opening note as the first message in the conversation' do
      request.accept!
      conversation = BetterTogether::Conversation.last
      expect(conversation.messages.count).to eq(1)
    end
  end

  describe '#decline!' do
    let(:request) do
      create(:better_together_message_request, sender: sender, recipient: recipient,
                                               platform: platform)
    end

    it 'marks the request as declined' do
      request.decline!
      expect(request.reload).to be_declined
      expect(request.responded_at).to be_present
    end

    it 'does not create a messaging grant' do
      expect { request.decline! }.not_to change(BetterTogether::PersonMessagingGrant, :count)
    end
  end

  describe 'scopes' do
    it 'returns pending requests via .pending' do
      req = create(:better_together_message_request, sender: sender, recipient: recipient,
                                                     platform: platform)
      expect(described_class.pending).to include(req)
    end
  end
end
